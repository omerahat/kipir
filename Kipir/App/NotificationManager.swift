import UserNotifications
import AppKit

@MainActor
protocol NotificationDelivery {
    func settings() async -> NotificationCapabilities
    func requestPermission() async throws
    func configure(delegate: UNUserNotificationCenterDelegate, categories: Set<UNNotificationCategory>)
    func add(_ request: UNNotificationRequest) async throws
    func remove(_ identifier: String)
}

@MainActor
final class SystemNotificationDelivery: NotificationDelivery {
    private let center = UNUserNotificationCenter.current()
    func settings() async -> NotificationCapabilities {
        let settings = await center.notificationSettings()
        return NotificationCapabilities(authorizationStatus: settings.authorizationStatus,
            alertSetting: settings.alertSetting, alertStyle: settings.alertStyle,
            notificationCenterSetting: settings.notificationCenterSetting, soundSetting: settings.soundSetting)
    }

    func requestPermission() async throws { _ = try await center.requestAuthorization(options: [.alert, .sound]) }
    func configure(delegate: UNUserNotificationCenterDelegate, categories: Set<UNNotificationCategory>) {
        center.delegate = delegate; center.setNotificationCategories(categories)
    }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func remove(_ identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}


@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private let delivery: NotificationDelivery
    private let defaults: UserDefaults
    private(set) var capabilities = NotificationCapabilities()
    var authorized: Bool { capabilities.canSubmit }
    private var visible: UUID?
    private var lastAttempted: UUID?
    private(set) var testing = false
    private(set) var testResultKey: String?
    private(set) var settingsNavigationKey: String?
    private var errorKey: String?
    private var errorDetail: String?
    var permissionText: String { L(capabilities.statusKey) }
    var deliveryDetailsText: String {
        L(capabilities.centerEnabled ? "notification.center.enabled" : "notification.center.disabled")
        + " · " + L(capabilities.soundEnabled ? "notification.sound.enabled" : "notification.sound.disabled")
    }
    var errorText: String? {
        errorKey.map { L($0) + (errorDetail.map { "\n" + $0 } ?? "") }
    }
    var onChange: (() -> Void)?
    var onAction: ((UUID, SchedulerAction) -> Void)?

    init(delivery: NotificationDelivery? = nil, defaults: UserDefaults = .standard) {
        self.delivery = delivery ?? SystemNotificationDelivery()
        self.defaults = defaults
        super.init()
        lastAttempted = defaults.string(forKey: "lastNotificationAttempt").flatMap(UUID.init(uuidString:))
        visible = lastAttempted
        updateLanguage()
    }
    func updateLanguage() {
        let actions = [
            UNNotificationAction(identifier: "start", title: L("break.start")),
            UNNotificationAction(identifier: "snooze", title: L("snooze")),
            UNNotificationAction(identifier: "skip", title: L("skip")),
            UNNotificationAction(identifier: "pause", title: L("pause"))
        ]
        delivery.configure(delegate: self, categories: [UNNotificationCategory(identifier: "break", actions: actions, intentIdentifiers: [])])
        Task { await refreshPermission() }
    }
    func refreshPermission() async {
        capabilities = await delivery.settings()
        onChange?()
    }
    func requestPermission() {
        Task {
            do { try await delivery.requestPermission() }
            catch { errorKey = "notification.permissionError"; errorDetail = error.localizedDescription }
            await refreshPermission()
        }
    }
    func sync(engine: BreakScheduler) {
        let due = engine.reminderID
        if let visible, visible != due || !engine.settings.notifications {
            delivery.remove(visible.uuidString)
            self.visible = nil
        }
        guard NotificationPolicy.shouldDeliver(enabled: engine.settings.notifications, authorized: authorized,
                                               due: due, sent: lastAttempted), let due else { return }
        lastAttempted = due; visible = due
        defaults.set(due.uuidString, forKey: "lastNotificationAttempt")
        let content = UNMutableNotificationContent()
        content.title = L("notification.title")
        content.body = L(engine.nextBreakIsLong ? "notification.long" : "notification.short")
        content.categoryIdentifier = "break"
        if engine.settings.sound && capabilities.soundEnabled { content.sound = .default }
        let request = UNNotificationRequest(identifier: due.uuidString, content: content, trigger: nil)
        Task {
            guard visible == due, engine.reminderID == due, engine.settings.notifications else { return }
            do {
                try await delivery.add(request)
                // Cancellation can happen while the OS accepts the request.
                if visible != due || engine.reminderID != due || !engine.settings.notifications {
                    delivery.remove(due.uuidString)
                }
            } catch { errorKey = "notification.deliveryError"; errorDetail = nil; onChange?() }
        }
    }
    // This path never synchronizes or mutates a real reminder episode.
    func testNotification(enabled: () -> Bool, sound: Bool) async {
        guard !testing else { return }
        testing = true; testResultKey = nil; onChange?()
        defer { testing = false; onChange?() }
        capabilities = await delivery.settings()
        if let reason = NotificationPolicy.testBlock(enabled: enabled(), permission: capabilities.permission) {
            testResultKey = reason; return
        }
        let content = UNMutableNotificationContent()
        content.title = L("notification.test.title")
        content.body = L("notification.test.body")
        if sound && capabilities.soundEnabled { content.sound = .default }
        do {
            try await delivery.add(UNNotificationRequest(identifier: "kipir.test." + UUID().uuidString, content: content, trigger: nil))
            testResultKey = capabilities.canShowDesktopAlerts ? "notification.test.submitted" : "notification.test.submittedQuiet"
        } catch { testResultKey = "notification.test.failed" }
    }

    // These are requests to the OS, not a guarantee of presentation or a Focus bypass.
    nonisolated static func presentationOptions(hasSound: Bool) -> UNNotificationPresentationOptions {
        hasSound ? [.banner, .list, .sound] : [.banner, .list]
    }

    func openNotificationSettings(open: (URL) -> Bool = { NSWorkspace.shared.open($0) }) {
        var components = URLComponents()
        components.scheme = "x-apple.systempreferences"
        components.path = "com.apple.Notifications-Settings.extension"
        if let identifier = Bundle.main.bundleIdentifier {
            components.queryItems = [URLQueryItem(name: "id", value: identifier)]
        }
        // Pane URLs are best effort; NSWorkspace acceptance cannot confirm the selected page.
        if let url = components.url, open(url) {
            settingsNavigationKey = "notification.settings.guidance"
        } else if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences"), open(app) {
            settingsNavigationKey = "notification.settings.guidance"
        } else { settingsNavigationKey = "notification.settings.failed" }
        onChange?()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(Self.presentationOptions(hasSound: notification.request.content.sound != nil))
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse) async {
        let identifier = response.notification.request.identifier
        let action = response.actionIdentifier
        await MainActor.run {
            if let id = UUID(uuidString: identifier) {
                let mapped: SchedulerAction?
                switch action {
                case "start": mapped = .startBreak
                case "snooze": mapped = .snooze
                case "skip": mapped = .skip
                case "pause": mapped = .togglePause
                default: mapped = nil
                }
                if let mapped { self.onAction?(id, mapped) }
            }
        }
    }
}

// Preserve quiet authorization and each OS setting instead of reducing them to one permission bit.
extension NotificationCapabilities {
    init(authorizationStatus: UNAuthorizationStatus, alertSetting: UNNotificationSetting,
         alertStyle: UNAlertStyle, notificationCenterSetting: UNNotificationSetting, soundSetting: UNNotificationSetting) {
        switch authorizationStatus {
        case .authorized: permission = .authorized
        case .provisional: permission = .provisional
        case .denied: permission = .denied
        default: permission = .unknown
        }
        alertsEnabled = alertSetting == .enabled
        switch alertStyle {
        case .banner: style = .banner
        case .alert: style = .alert
        default: style = .none
        }
        centerEnabled = notificationCenterSetting == .enabled
        soundEnabled = soundSetting == .enabled
    }
}
