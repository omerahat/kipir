import Foundation

final class BreakScheduler {
    private(set) var settings: Settings
    private var saved: Checkpoint
    private let now: () -> TimeInterval
    private let date: () -> Date
    private let idle: () -> TimeInterval
    private var previousTime: TimeInterval?
    private var previousIdle: TimeInterval?
    private var pending: TimeInterval = 0
    private var naturalCompletionSound: Bool?
    private(set) var suspended = false
    var reminderID: UUID? {
        saved.phase == .due && !paused && !meeting && !suspended ? saved.dueID : nil
    }
    private var isIdle = false
    private(set) var exercises: ExerciseSequenceController?

    init(settings: Settings = Settings(), checkpoint: Checkpoint? = nil,
         now: @escaping () -> TimeInterval, date: @escaping () -> Date,
         idle: @escaping () -> TimeInterval) {
        self.settings = settings.validated()
        self.now = now; self.date = date; self.idle = idle
        saved = checkpoint.flatMap { $0.isValid ? $0 : nil } ??
            Checkpoint(target: self.settings.work, today: DailyStats(day: Calendar.current.startOfDay(for: date())))
        if saved.phase == .onBreak { exercises = ExerciseSequenceController(long: saved.isLongBreak, duration: saved.breakDuration, elapsed: saved.breakDuration - saved.breakRemaining) }
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
    var status: WorkStatus {
        if suspended { return .suspended }
        if paused { return .paused }
        if meeting { return .meeting }
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
        // Expiration resumes only from a fresh baseline, never credits the frozen crossing sample.
        if reconcileMeeting() { baseline(); return }
        guard t.isFinite, i.isFinite, i >= 0 else {
            pending = 0; previousTime = nil; previousIdle = nil; isIdle = true; return
        }
        let oldTime = previousTime, oldIdle = previousIdle
        previousTime = t; previousIdle = i
        isIdle = i >= settings.afk
        guard let oldTime, let oldIdle, !changedDay else { pending = 0; return }
        let delta = t - oldTime
        guard delta > 0, delta <= 10, !suspended, !paused, !meeting else { pending = 0; return }
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
            guard !isIdle else { pending = 0; return }
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
            guard !paused, !meeting, !suspended, saved.phase != .onBreak else { return }
            saved.isLongBreak = nextBreakIsLong
            saved.breakDuration = saved.isLongBreak ? settings.longBreak : settings.shortBreak
            saved.breakRemaining = saved.breakDuration
            saved.phase = .onBreak
            exercises = ExerciseSequenceController(long: saved.isLongBreak, duration: saved.breakDuration)
        case .snooze:
            guard saved.phase == .due, !paused, !meeting, !suspended else { return }
            saved.target = saved.activeWork + settings.snooze
            saved.snoozed = true; saved.phase = .working
        case .skip:
            naturalCompletionSound = nil
            guard saved.phase == .due || saved.phase == .onBreak else { return }
            resetInterval()
        case .togglePause: naturalCompletionSound = nil; saved.paused.toggle()
        case .toggleMeeting: naturalCompletionSound = nil; saved.meeting.toggle(); saved.meetingDeadline = nil
        case .reset:
            naturalCompletionSound = nil
            resetInterval(); saved.completedShorts = 0; saved.paused = false; saved.meeting = false; saved.meetingDeadline = nil
        }
        baseline(); refreshReminder()
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
        baseline(); refreshReminder()
    }

    @discardableResult private func reconcileMeeting() -> Bool {
        guard saved.meeting else { saved.meetingDeadline = nil; return false }
        guard let deadline = saved.meetingDeadline else { return false }
        let remaining = deadline.timeIntervalSince(date())
        // A backward clock jump beyond the supported one-hour horizon cancels timed mode.
        guard remaining.isFinite, remaining > 0, remaining <= 3600 else {
            saved.meeting = false; saved.meetingDeadline = nil; pending = 0; return true
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
        if !saved.snoozed && saved.phase != .onBreak {
            saved.target = settings.work
            saved.phase = activeWork >= saved.target ? .due : .working
        }
        baseline(); refreshReminder()
    }

    func navigateExercise(_ offset: Int) {
        tick()
        guard saved.phase == .onBreak else { return }
        exercises?.navigate(offset)
    }

    private func baseline() {
        let t = now(), i = idle()
        previousTime = t.isFinite ? t : nil
        previousIdle = i.isFinite && i >= 0 ? i : nil
        isIdle = !i.isFinite || i < 0 || i >= settings.afk
        pending = 0
    }
    @discardableResult private func rollover() -> Bool {
        let day = Calendar.current.startOfDay(for: date())
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
