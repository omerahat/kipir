import Foundation

struct MenuBarStatusFormatter {
    let status: WorkStatus
    let remaining: TimeInterval
    var minutes: Int { remaining.isFinite ? Int(min(Double(Int.max / 2), ceil(max(0, remaining) / 60))) : 0 }
    var symbol: String {
        switch status {
        case .paused: return "pause.fill"
        case .meeting: return "person.2"
        case .idle: return "moon"
        case .suspended: return "powersleep"
        case .due: return "figure.walk.circle.fill"
        default: return "figure.walk"
        }
    }
    var textKey: String? {
        switch status {
        case .working, .idle: return "menubar.minutes"
        case .due: return "menubar.due"
        case .onBreak: return "menubar.break"
        case .meeting: return "menubar.meeting"
        case .suspended: return "menubar.suspended"
        case .paused: return nil
        }
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
    static func consume(from engine: BreakScheduler, play: () -> Void) {
        if engine.consumeBreakCompletion() == true && engine.settings.breakEndSound { play() }
    }
}
