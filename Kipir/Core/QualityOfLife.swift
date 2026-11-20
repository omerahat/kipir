import Foundation

struct MenuBarStatusFormatter {
    let status: WorkStatus
    let remaining: TimeInterval
    /// Icon-only menu bar presentation (`Settings.menuBarStyle == "icon"`). Status is then carried by the symbol,
    /// the tooltip and the accessibility label only.
    var iconOnly = false
    /// A Due episode exists even though another state (meeting, pause, off hours) is shown: say "Break", not "0 min".
    var breakDue = false
    var showsText: Bool { !iconOnly }
    /// Full status and remaining time for tooltips and VoiceOver; independent of the visible style.
    func summary(_ localize: (String) -> String) -> String {
        localize("app.name") + ", " + localize("status." + status.rawValue)
            + ", " + String(format: localize("menubar.minutes"), minutes)
    }
    var minutes: Int { remaining.isFinite ? Int(min(Double(Int.max / 2), ceil(max(0, remaining) / 60))) : 0 }
    var symbol: String {
        switch status {
        case .paused: return "pause.fill"
        case .meeting: return "person.2"
        case .idle: return "moon"
        case .suspended: return "powersleep"
        case .offHours: return "moon.zzz"
        case .due: return "figure.walk.circle.fill"
        case .onBreak: return "figure.walk.motion"
        case .working: return "figure.walk"
        }
    }
    /// The visible text is always the remaining minutes, except "Break" once a break is due. State is carried
    /// by the icon in its fixed slot, so a pause, meeting or break never changes the label's width
    /// (pre-release Fix 2). The full status stays in `summary`.
    private var showsDue: Bool { status == .due || (breakDue && status != .onBreak) }
    var textKey: String { showsDue ? "menubar.due" : "menubar.minutes" }
    func text(_ localize: (String) -> String) -> String {
        showsDue ? localize(textKey) : String(format: localize(textKey), minutes)
    }
}

/// Trim end of the popover countdown ring: the remaining share clamped to 0...1 (non-finite input draws nothing).
enum CountdownRingMath {
    static func clamped(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : 0 }
}

/// Fixed geometry of the menu bar label. The text slot is measured once over every string the label can show
/// in every supported language, so state, countdown and language changes never resize the status item.
enum MenuBarLabelLayout {
    static let iconSlot: Double = 18
    static let gap: Double = 4
    /// Work can be up to 240 minutes, snooze 60, breaks 60: three digits cover every countdown.
    static let widestMinutes = 888

    /// Every text the timer-style label can display, for the given localization tables (key -> format).
    static func candidates(tables: [[String: String]]) -> [String] {
        tables.flatMap { table -> [String] in
            var values: [String] = []
            if let format = table["menubar.minutes"] {
                values += [8, 88, widestMinutes].map { String(format: format, $0) }
            }
            if let due = table["menubar.due"] { values.append(due) }
            return values
        }
    }
    /// Width of the text slot in points, rounded up so nothing is clipped.
    static func textSlotWidth(candidates: [String], measure: (String) -> Double) -> Double {
        let widest = candidates.map(measure).filter { $0.isFinite && $0 >= 0 }.max() ?? 0
        return (widest + 1).rounded(.up)
    }
    static func totalWidth(textSlot: Double, iconOnly: Bool) -> Double {
        iconOnly ? iconSlot : iconSlot + gap + textSlot
    }
}

/// Interface language. `nil`/"system" follows the macOS preferred languages (including the per-app language
/// set in System Settings); an explicit "tr" or "en" overrides it. Unsupported system languages use English.
enum AppLanguage {
    static let supported = ["tr", "en"]
    static let fallback = "en"
    static func normalizedPreference(_ stored: String?) -> String {
        guard let stored, supported.contains(stored) else { return "system" }
        return stored
    }
    static func resolve(preference: String?, preferredLanguages: [String]) -> String {
        let value = normalizedPreference(preference)
        if value != "system" { return value }
        for identifier in preferredLanguages {
            let code = identifier.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
            if let code, supported.contains(code) { return code }
        }
        return fallback
    }
}

// Shared permission policy; the native adapter maps OS authorization into these states.
enum NotificationPermission { case authorized, provisional, denied, unknown }

struct NotificationCapabilities {
    enum AlertStyle { case none, banner, alert }
    var permission: NotificationPermission = .unknown
    var alertsEnabled = false
    var style: AlertStyle = .none
    var centerEnabled = false
    var soundEnabled = false
    var canSubmit: Bool { permission == .authorized || permission == .provisional }
    var canShowDesktopAlerts: Bool { permission == .authorized && alertsEnabled && style != .none }
    var statusKey: String {
        switch permission {
        case .unknown: return "permission.unknown"
        case .denied: return "permission.denied"
        case .provisional: return "permission.quiet"
        case .authorized:
            if canShowDesktopAlerts { return "permission.allowed" }
            return centerEnabled ? "permission.centerOnly" : "permission.alertsDisabled"
        }
    }
}
extension NotificationPolicy {
    /// Meeting mode consumes the current Due episode's reminder instead of postponing it: the returned value is
    /// stored as the last attempted reminder, so ending the meeting never replays it. Later episodes get new
    /// identifiers and notify normally (DECISIONS 028).
    static func markingMeetingSuppressed(sent: UUID?, meeting: Bool, dueID: UUID?) -> UUID? {
        guard meeting, let dueID else { return sent }
        return dueID
    }
    static func testBlock(enabled: Bool, permission: NotificationPermission) -> String? {
        if !enabled { return "notification.test.disabled" }
        switch permission {
        case .authorized, .provisional: return nil
        case .denied: return "permission.denied"
        case .unknown: return "permission.unknown"
        }
    }
}

// Selection is derived from the existing six values, never stored separately.
enum TimingPreset: String, CaseIterable {
    case quick, balanced
    func apply(to settings: inout Settings) {
        settings.work = self == .quick ? 1500 : 2700
        settings.shortBreak = self == .quick ? 60 : 120
        settings.longBreak = 300
        settings.longEvery = 3
        settings.afk = 90
        settings.snooze = self == .quick ? 300 : 600
    }
    static func match(_ settings: Settings) -> TimingPreset? {
        allCases.first { preset in
            var candidate = settings; preset.apply(to: &candidate)
            return candidate == settings
        }
    }
}

// Controller supplies native playback; consuming a disabled event prevents later replay.
enum BreakCompletionFeedback {
    /// One consumption of the scheduler's completion event, shared by the sound and the on-screen notice.
    /// The natural-break event is deliberately not consumed here; the controller reads it separately.
    struct Outcome: Equatable {
        /// A scheduler-credited completion occurred (never true for skip, manual finish, pause or sleep).
        var completed = false
        /// Preference was true when the break completed and is still true now, and meeting mode is off.
        var playSound = false
    }

    @discardableResult
    static func consume(from engine: BreakScheduler) -> Outcome {
        var outcome = Outcome()
        if let captured = engine.consumeBreakCompletion() {
            outcome.completed = true
            // Meeting mode silences the sound; the event is still consumed so it never plays later.
            outcome.playSound = captured && engine.settings.breakEndSound && !engine.meeting
        }
        return outcome
    }

    @discardableResult
    static func consume(from engine: BreakScheduler, play: () -> Void) -> Outcome {
        let outcome = consume(from: engine)
        if outcome.playSound { play() }
        return outcome
    }
}

/// Short-lived, non-persistent message under the timer. It stays pending (unseen) for up to `pendingLifetime`
/// so a popover opened later still shows it, then lives `lifetime` from the moment the popover actually
/// displayed it. Expiry is evaluated from the controller heartbeat using monotonic time supplied by the caller;
/// no timer is involved.
struct TransientNotice: Equatable {
    enum Kind: Equatable { case breakCompleted(today: Int), naturalBreak }
    /// Visible lifetime once displayed.
    static let lifetime: TimeInterval = 6
    /// How long an event waits for the popover to be opened.
    static let pendingLifetime: TimeInterval = 15 * 60
    let kind: Kind
    /// Monotonic time of the event; also identifies the notice for the view.
    let postedAt: TimeInterval
    /// Monotonic time the popover first displayed it, nil while still pending.
    private(set) var displayedAt: TimeInterval?

    init(_ kind: Kind, now: TimeInterval) { self.kind = kind; postedAt = now }
    var isPending: Bool { displayedAt == nil }
    func isVisible(at now: TimeInterval) -> Bool {
        guard now.isFinite else { return false }
        if let displayedAt { return now < displayedAt + Self.lifetime }
        return now < postedAt + Self.pendingLifetime
    }
    /// The popover displayed this notice: the 6 s lifetime starts now. Idempotent once displayed; an expired
    /// notice yields nil.
    func markingDisplayed(at now: TimeInterval) -> TransientNotice? {
        guard isVisible(at: now) else { return nil }
        guard displayedAt == nil else { return self }
        var copy = self; copy.displayedAt = now
        return copy
    }
    var textKey: String {
        switch kind {
        case .breakCompleted: return "ui.notice.breakCompleted"
        case .naturalBreak: return "ui.notice.naturalBreak"
        }
    }
    /// Value substituted into `textKey`, if any.
    var count: Int? {
        if case .breakCompleted(let today) = kind { return today }
        return nil
    }

    /// A completion outranks a natural break reported in the same publish and any newer event replaces an older
    /// one; no event means the current notice is kept until it expires.
    static func next(current: TransientNotice?, outcome: BreakCompletionFeedback.Outcome, naturalBreak: Bool = false,
                     todayBreaks: Int, now: TimeInterval) -> TransientNotice? {
        if outcome.completed { return TransientNotice(.breakCompleted(today: max(0, todayBreaks)), now: now) }
        if naturalBreak { return TransientNotice(.naturalBreak, now: now) }
        guard let current, current.isVisible(at: now) else { return nil }
        return current
    }
}

// Presentation state derived from the stored preference plus OS capabilities; the preference is never rewritten.
enum NotificationEffectiveState: Equatable {
    case off, needsPermission, denied, limited, active

    enum PrimaryAction: Equatable { case none, requestPermission, openSettings }

    static func derive(enabled: Bool, capabilities: NotificationCapabilities) -> NotificationEffectiveState {
        guard enabled else { return .off }
        switch capabilities.permission {
        case .unknown: return .needsPermission
        case .denied: return .denied
        case .provisional: return .limited
        case .authorized: return capabilities.canShowDesktopAlerts ? .active : .limited
        }
    }
    var primaryAction: PrimaryAction {
        switch self {
        case .needsPermission: return .requestPermission
        case .denied, .limited: return .openSettings
        case .off, .active: return .none
        }
    }
    var statusKey: String { "ui.notif.state." + String(describing: self) }
    var symbol: String {
        switch self {
        case .off: return "bell.slash"
        case .needsPermission: return "bell.badge"
        case .denied: return "bell.slash.fill"
        case .limited: return "exclamationmark.triangle"
        case .active: return "bell.fill"
        }
    }
    var needsAttention: Bool { self == .denied || self == .limited }
}

// Break lengths are chosen from human-readable presets; storage stays in seconds.
enum BreakDurationOptions {
    static let short: [TimeInterval] = [30, 60, 120, 180, 300]
    static let long: [TimeInterval] = [180, 300, 600, 900]

    static func isPreset(_ seconds: TimeInterval, in options: [TimeInterval]) -> Bool { options.contains(seconds) }

    /// Whole minutes and remaining seconds of a stored duration; non-finite or negative values give zero.
    static func parts(_ seconds: TimeInterval) -> (minutes: Int, seconds: Int) {
        guard seconds.isFinite, seconds > 0 else { return (0, 0) }
        let total = Int(seconds.rounded())
        return (total / 60, total % 60)
    }
    /// Localization key (format takes the listed integers) and arguments for a duration label.
    static func label(_ seconds: TimeInterval) -> (key: String, values: [Int]) {
        let p = parts(seconds)
        if p.minutes == 0 { return ("ui.duration.seconds", [p.seconds]) }
        if p.seconds == 0 { return ("ui.duration.minutes", [p.minutes]) }
        return ("ui.duration.minutesSeconds", [p.minutes, p.seconds])
    }
}

// Working-hours editing helpers. Minutes are local wall-clock minutes from midnight, as stored.
enum WorkingHoursEditing {
    static func minutes(of date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    /// A date on `reference`'s day at the given wall-clock time. Uses calendar arithmetic, not
    /// `startOfDay + minutes * 60`, so daylight-saving days do not shift the displayed time.
    static func date(forMinutes minutes: Int, calendar: Calendar = .current, reference: Date = Date()) -> Date {
        let clamped = min(1439, max(0, minutes))
        return calendar.date(bySettingHour: clamped / 60, minute: clamped % 60, second: 0, of: reference)
            ?? calendar.startOfDay(for: reference).addingTimeInterval(TimeInterval(clamped * 60))
    }
    /// Weekday numbers 1...7 starting at the calendar's first weekday.
    static func orderedWeekdays(calendar: Calendar) -> [Int] {
        let first = (1...7).contains(calendar.firstWeekday) ? calendar.firstWeekday : 1
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }
    static func weekdayName(_ weekday: Int, locale: Locale, short: Bool) -> String {
        guard (1...7).contains(weekday) else { return "" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = short ? calendar.shortWeekdaySymbols : calendar.weekdaySymbols
        return symbols[weekday - 1]
    }
    /// Toggles a day but never removes the last one; `validated()` would otherwise silently restore Mon-Fri.
    static func toggling(_ weekday: Int, in weekdays: [Int]) -> [Int] {
        guard (1...7).contains(weekday) else { return weekdays }
        var days = Set(weekdays.filter { (1...7).contains($0) })
        if days.contains(weekday) { if days.count > 1 { days.remove(weekday) } } else { days.insert(weekday) }
        return days.sorted()
    }
    /// Applies a new start or end; an edit that would make both equal (which `validated()` resets) is ignored.
    static func updating(_ hours: WorkingHours, start: Int? = nil, end: Int? = nil) -> WorkingHours {
        var result = hours
        let newStart = start ?? hours.start, newEnd = end ?? hours.end
        guard (0..<1440).contains(newStart), (0..<1440).contains(newEnd), newStart != newEnd else { return hours }
        result.start = newStart; result.end = newEnd
        return result
    }
    static func crossesMidnight(_ hours: WorkingHours) -> Bool { hours.end < hours.start }
}
