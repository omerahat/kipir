import Foundation

final class BreakScheduler {
    private(set) var settings: Settings
    private var saved: Checkpoint
    private let now: () -> TimeInterval
    private let date: () -> Date
    private let idle: () -> TimeInterval
    private let calendar: Calendar
    private var previousTime: TimeInterval?
    private var previousIdle: TimeInterval?
    private var pending: TimeInterval = 0
    private var naturalCompletionSound: Bool?
    private(set) var suspended = false
    /// Whether the injected wall date lies inside the working window; refreshed on every tick.
    private var inWindow = true
    // Natural-break chain (DECISIONS 018). `awayOpen` is false while the chain is tainted: after a restart,
    // an invalid/unknown gap, or any state that cannot accrue. Only an observed input opens a fresh chain.
    private var awayOpen = false
    private var away: TimeInterval = 0
    private var naturalResetPending = false
    private var naturalNoticeReady = false
    private static let inputTolerance = 0.05
    /// The deliverable reminder. Meeting mode only withholds delivery; the Due episode itself still exists
    /// (`checkpoint.dueID`) and the timer keeps running (DECISIONS 028).
    var reminderID: UUID? {
        saved.phase == .due && !paused && !meeting && !suspended && inWindow ? saved.dueID : nil
    }
    private var isIdle = false
    private(set) var exercises: ExerciseSequenceController?

    init(settings: Settings = Settings(), checkpoint: Checkpoint? = nil,
         now: @escaping () -> TimeInterval, date: @escaping () -> Date,
         idle: @escaping () -> TimeInterval, calendar: Calendar = .autoupdatingCurrent) {
        self.settings = settings.validated()
        self.now = now; self.date = date; self.idle = idle; self.calendar = calendar
        saved = checkpoint.flatMap { $0.isValid ? $0 : nil } ??
            Checkpoint(target: self.settings.work, today: DailyStats(day: calendar.startOfDay(for: date())))
        inWindow = self.settings.workingHours.contains(date(), calendar: calendar)
        // A checkpoint saved off hours that is restored inside the window is a genuine out-to-in transition.
        if saved.wasOffHours && inWindow { restartIntervalOnWindowEntry() }
        saved.wasOffHours = !inWindow
        if saved.phase == .onBreak { exercises = makeExercises(elapsed: saved.breakDuration - saved.breakRemaining) }
        rollover()
        reconcileMeeting()
        baseline()
        refreshReminder()
    }

    var activeWork: TimeInterval { saved.activeWork }
    var today: DailyStats { saved.today }
    var checkpoint: Checkpoint { saved }
    var isLongBreak: Bool { saved.isLongBreak }
    var nextBreakIsLong: Bool { saved.completedShorts >= settings.longEvery }
    var paused: Bool { saved.paused }
    var meeting: Bool { saved.meeting }
    var meetingRemaining: TimeInterval? {
        saved.meetingDeadline.map { max(0, $0.timeIntervalSince(date())) }
    }
    var remaining: TimeInterval {
        saved.phase == .onBreak ? saved.breakRemaining : max(0, saved.target - saved.activeWork)
    }
    var progress: Double {
        if saved.phase == .onBreak {
            return min(1, max(0, 1 - remaining / saved.breakDuration))
        }
        return min(1, max(0, activeWork / max(1, saved.target)))
    }
    /// Share of the current countdown still left, 1 at its start and 0 when it reaches zero; the popover ring
    /// draws exactly this. A snoozed interval counts down from the snooze length rather than the whole target.
    var remainingFraction: Double {
        let total: TimeInterval
        if saved.phase == .onBreak { total = saved.breakDuration }
        else { total = saved.snoozed ? settings.snooze : saved.target }
        guard total.isFinite, total > 0, remaining.isFinite else { return 0 }
        return min(1, max(0, remaining / total))
    }
    /// A Due episode the user can act on from the panel: also while meeting mode silences the reminder.
    var breakDueActionable: Bool { saved.phase == .due && (status == .due || status == .meeting) }
    var status: WorkStatus {
        if suspended { return .suspended }
        if paused { return .paused }
        // A running break stays visible as a break; meeting mode only silences interruptions.
        if saved.phase == .onBreak { return .onBreak }
        if meeting { return .meeting }
        if !inWindow && saved.phase != .onBreak { return .offHours }
        switch saved.phase {
        case .due: return .due
        case .onBreak: return .onBreak
        case .working: return isIdle ? .idle : .working
        }
    }

    func tick() {
        let t = now(), i = idle()
        let changedDay = rollover()
        defer { refreshReminder() }
        // Meeting mode never freezes time, so its expiration needs no rebaseline (DECISIONS 028).
        reconcileMeeting()
        // Entering or leaving the working window rebaselines like meeting expiration; the crossing sample is discarded.
        // A break already in progress keeps counting down (DECISIONS 019), so its sample is not discarded.
        // Entering the window starts a new working period: a stale interval or Due episode restarts (DECISIONS 025).
        if refreshWindow() {
            if inWindow { restartIntervalOnWindowEntry() }
            if saved.phase != .onBreak { dropAwayChain(); baseline(); return }
        }
        guard t.isFinite, i.isFinite, i >= 0 else {
            pending = 0; previousTime = nil; previousIdle = nil; isIdle = true; dropAwayChain(); return
        }
        let oldTime = previousTime, oldIdle = previousIdle
        previousTime = t; previousIdle = i
        isIdle = i >= settings.afk
        guard let oldTime, let oldIdle else { pending = 0; dropAwayChain(); return }
        let delta = t - oldTime
        // The away chain may continue across a day rollover; only work credit is withheld for that sample.
        if trackAway(delta: delta, oldIdle: oldIdle, idle: i) { pending = 0; return }
        guard !changedDay else { pending = 0; return }
        // A repeated sample at the same instant carries no information; keep the unconfirmed span intact so
        // back-to-back calls (for example rapid meeting toggles) never discard credit.
        if delta == 0 { return }
        guard delta > 0, delta <= 10, !suspended, !paused else { pending = 0; return }
        switch saved.phase {
        case .onBreak:
            pending = 0
            exercises?.advance(min(delta, saved.breakRemaining))
            saved.breakRemaining = max(0, saved.breakRemaining - delta)
            if saved.breakRemaining == 0 {
                naturalCompletionSound = settings.breakEndSound
                saved.today.breaks += 1
                saved.completedShorts = saved.isLongBreak ? 0 : min(10, saved.completedShorts + 1)
                resetInterval()
            }
        case .working, .due:
            guard inWindow, !isIdle else { pending = 0; return }
            let eventGap = delta + oldIdle - i
            if eventGap > 0.001 {
                // Confirm only spans bounded by input; a long AFK gap never earns its threshold.
                let available = pending + delta
                let credit = eventGap < settings.afk ? max(0, available - i) : max(0, delta - i)
                saved.activeWork += credit
                saved.today.activeSeconds += credit
                pending = min(i, available)
            } else { pending += delta }
            if saved.activeWork >= saved.target { saved.phase = .due }
        }
    }

    func perform(_ action: SchedulerAction) {
        tick()
        switch action {
        case .startBreak:
            guard !paused, !suspended, saved.phase != .onBreak else { return }
            clearNaturalNotice()
            saved.isLongBreak = nextBreakIsLong
            saved.breakDuration = saved.isLongBreak ? settings.longBreak : settings.shortBreak
            saved.breakRemaining = saved.breakDuration
            saved.phase = .onBreak
            saved.exerciseRotation = saved.exerciseRotation >= 1_000_000 ? 0 : saved.exerciseRotation + 1
            saved.breakFocus = settings.exerciseFocus
            exercises = makeExercises(elapsed: 0)
        case .snooze:
            guard saved.phase == .due, !paused, !suspended else { return }
            saved.target = saved.activeWork + settings.snooze
            saved.snoozed = true; saved.phase = .working
        case .skip:
            naturalCompletionSound = nil; clearNaturalNotice()
            guard saved.phase == .due || saved.phase == .onBreak else { return }
            resetInterval()
        case .togglePause: naturalCompletionSound = nil; saved.paused.toggle()
        case .toggleMeeting: naturalCompletionSound = nil; saved.meeting.toggle(); saved.meetingDeadline = nil
        case .reset:
            naturalCompletionSound = nil; clearNaturalNotice()
            resetInterval(); saved.completedShorts = 0; saved.paused = false; saved.meeting = false; saved.meetingDeadline = nil
        }
        baseline(); refreshReminder()
    }

    /// Ephemeral event: true exactly once after the scheduler reset the work interval because of a verified
    /// natural break, delivered on the first input observed after the reset. Never persisted.
    func consumeNaturalBreak() -> Bool {
        defer { naturalNoticeReady = false }
        return naturalNoticeReady
    }

    // Ephemeral event: nil means no completion; Bool captures the preference at completion.
    func consumeBreakCompletion() -> Bool? {
        defer { naturalCompletionSound = nil }
        return naturalCompletionSound
    }

    func setMeeting(_ enabled: Bool, duration: TimeInterval? = nil) {
        if let duration, ![900.0, 1800, 3600].contains(duration) { return }
        tick()
        if enabled { naturalCompletionSound = nil }
        saved.meeting = enabled
        saved.meetingDeadline = enabled ? duration.map { date().addingTimeInterval($0) } : nil
        reconcileMeeting()
        // No rebaseline: toggling meeting mode must not drop unconfirmed credit or the away chain.
        refreshReminder()
    }

    @discardableResult private func reconcileMeeting() -> Bool {
        guard saved.meeting else { saved.meetingDeadline = nil; return false }
        guard let deadline = saved.meetingDeadline else { return false }
        let remaining = deadline.timeIntervalSince(date())
        // A backward clock jump beyond the supported one-hour horizon cancels timed mode.
        guard remaining.isFinite, remaining > 0, remaining <= 3600 else {
            saved.meeting = false; saved.meetingDeadline = nil; return true
        }
        return false
    }

    func setSuspended(_ value: Bool) {
        tick()
        if value { naturalCompletionSound = nil }
        suspended = value; baseline(); refreshReminder()
    }

    func updateSettings(_ value: Settings) {
        tick(); settings = value.validated()
        // Toggling or editing the window in Settings never restarts the interval; only a clock transition does.
        inWindow = settings.workingHours.contains(date(), calendar: calendar); saved.wasOffHours = !inWindow
        if !saved.snoozed && saved.phase != .onBreak {
            saved.target = settings.work
            // Off hours never starts a Due episode, but an existing one is preserved.
            saved.phase = activeWork >= saved.target && (inWindow || saved.phase == .due) ? .due : .working
        }
        baseline(); refreshReminder()
    }

    func navigateExercise(_ offset: Int) {
        tick()
        guard saved.phase == .onBreak else { return }
        exercises?.navigate(offset)
    }

    private func makeExercises(elapsed: Double) -> ExerciseSequenceController {
        ExerciseSequenceController(long: saved.isLongBreak, duration: saved.breakDuration,
                                   focus: ExerciseFocus(rawValue: saved.breakFocus ?? "all") ?? .all,
                                   rotation: saved.exerciseRotation, elapsed: elapsed)
    }
    private func baseline() {
        let t = now(), i = idle()
        let oldTime = previousTime, oldIdle = previousIdle
        previousTime = t.isFinite ? t : nil
        previousIdle = i.isFinite && i >= 0 ? i : nil
        isIdle = !i.isFinite || i < 0 || i >= settings.afk
        pending = 0
        // The discarded crossing sample must not hide input from the away chain (for example the unlock keypress).
        guard t.isFinite, i.isFinite, i >= 0 else { dropAwayChain(); return }
        var gapKnown = false, inputSeen = false
        if let oldTime, let oldIdle, t >= oldTime {
            let gap = t - oldTime
            gapKnown = gap <= 10
            inputSeen = i < oldIdle + gap - Self.inputTolerance
        }
        // With no input since the chain opened, idle is at least the verified away time.
        if awayOpen && i + Self.inputTolerance < away { inputSeen = true }
        if suspended { inputSeen = false }
        if inputSeen { awayOpen = true; away = 0; armNaturalNotice() }
        else if !gapKnown { dropAwayChain() }
        if !canAccrueAway { dropAwayChain() }
    }
    private var canAccrueAway: Bool {
        (saved.phase == .working || saved.phase == .due) && !paused && inWindow
    }
    private func dropAwayChain() { awayOpen = false; away = 0 }
    private func armNaturalNotice() {
        if naturalResetPending { naturalResetPending = false; naturalNoticeReady = true }
    }
    private func clearNaturalNotice() { naturalResetPending = false; naturalNoticeReady = false }
    /// Returns true when this sample reset the work interval.
    private func trackAway(delta: TimeInterval, oldIdle: TimeInterval, idle i: TimeInterval) -> Bool {
        let inputSeen = delta > 0 && i < oldIdle + delta - Self.inputTolerance
        let validDelta = delta > 0 && delta <= 10
        // A repeated sample at the same instant (perform/save right after a heartbeat) carries no information.
        if delta == 0 { return false }
        guard canAccrueAway else {
            dropAwayChain()
            if inputSeen { armNaturalNotice() }
            return false
        }
        if suspended {
            // Lock, display-off and inactive sessions keep the heartbeat but cannot be user input, and system sleep
            // stops monotonic uptime, so a coalesced heartbeat of any finite positive length is verified away time.
            // Work credit and break countdown keep their own 10 s rule (DECISIONS 025).
            if delta > 0 && delta.isFinite && awayOpen { away += delta; return applyNaturalBreak() }
            dropAwayChain(); return false
        }
        if inputSeen { awayOpen = true; away = 0; armNaturalNotice(); return false }
        if validDelta && awayOpen { away += delta; return applyNaturalBreak() }
        dropAwayChain()
        return false
    }
    private func applyNaturalBreak() -> Bool {
        guard settings.naturalBreak > 0, away >= settings.effectiveNaturalBreak else { return false }
        guard saved.activeWork > 0 || saved.phase == .due || saved.snoozed else { return false }
        resetInterval()
        pending = 0
        naturalResetPending = true; naturalNoticeReady = false
        return true
    }
    @discardableResult private func refreshWindow() -> Bool {
        let value = settings.workingHours.contains(date(), calendar: calendar)
        guard value != inWindow else { return false }
        inWindow = value; saved.wasOffHours = !value
        return true
    }
    /// A new working period begins: a stale interval or Due episode restarts without touching today's totals or
    /// the short/long cycle, and without a natural-break notice. A running break is never interrupted.
    private func restartIntervalOnWindowEntry() {
        guard saved.phase != .onBreak,
              saved.activeWork > 0 || saved.phase == .due || saved.snoozed else { return }
        resetInterval(); pending = 0
    }
    @discardableResult private func rollover() -> Bool {
        let day = calendar.startOfDay(for: date())
        guard day != saved.today.day else { return false }
        saved.today = DailyStats(day: day); pending = 0; return true
    }
    private func resetInterval() {
        exercises = nil
        saved.activeWork = 0; saved.target = settings.work; saved.phase = .working
        saved.breakRemaining = 0; saved.isLongBreak = false; saved.snoozed = false
    }
    private func refreshReminder() {
        if saved.phase == .due {
            if saved.dueID == nil { saved.dueID = UUID() }
        } else { saved.dueID = nil }
    }
}
