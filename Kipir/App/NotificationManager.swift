import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private(set) var authorized = false
    private var visible: UUID?
    private var lastAttempted: UUID?
    private var permissionKey = "permission.unknown"
    private var errorKey: String?
    private var errorDetail: String?
    var permissionText: String { L(permissionKey) }
    var errorText: String? {
        errorKey.map { L($0) + (errorDetail.map { "\n" + $0 } ?? "") }
    }
    var onChange: (() -> Void)?
    var onAction: ((UUID, SchedulerAction) -> Void)?

    override init() {
        super.init()
        lastAttempted = UserDefaults.standard.string(forKey: "lastNotificationAttempt").flatMap(UUID.init(uuidString:))
        visible = lastAttempted
        center.delegate = self
        updateLanguage()
    }
    func updateLanguage() {
        let actions = [
            UNNotificationAction(identifier: "start", title: L("break.start")),
            UNNotificationAction(identifier: "snooze", title: L("snooze")),
            UNNotificationAction(identifier: "skip", title: L("skip")),
            UNNotificationAction(identifier: "pause", title: L("pause"))
        ]
        center.setNotificationCategories([UNNotificationCategory(identifier: "break", actions: actions, intentIdentifiers: [])])
        Task { await refreshPermission() }
    }
    func refreshPermission() async {
        let settings = await center.notificationSettings()
        authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        switch settings.authorizationStatus {
        case .authorized, .provisional: permissionKey = "permission.allowed"
        case .denied: permissionKey = "permission.denied"
        default: permissionKey = "permission.unknown"
        }
        onChange?()
    }
    func requestPermission() {
        Task {
            do { _ = try await center.requestAuthorization(options: [.alert, .sound]) }
            catch { errorKey = "notification.permissionError"; errorDetail = error.localizedDescription }
            await refreshPermission()
        }
    }
    func sync(engine: BreakScheduler) {
        let due = engine.reminderID
        if let visible, visible != due || !engine.settings.notifications {
            center.removePendingNotificationRequests(withIdentifiers: [visible.uuidString])
            center.removeDeliveredNotifications(withIdentifiers: [visible.uuidString])
            self.visible = nil
        }
        guard NotificationPolicy.shouldDeliver(enabled: engine.settings.notifications, authorized: authorized,
                                               due: due, sent: lastAttempted), let due else { return }
        lastAttempted = due; visible = due
        UserDefaults.standard.set(due.uuidString, forKey: "lastNotificationAttempt")
        let content = UNMutableNotificationContent()
        content.title = L("notification.title")
        content.body = L(engine.nextBreakIsLong ? "notification.long" : "notification.short")
        content.categoryIdentifier = "break"
        if engine.settings.sound { content.sound = .default }
        let request = UNNotificationRequest(identifier: due.uuidString, content: content, trigger: nil)
        center.add(request) { [weak self] error in
            if error != nil {
                Task { @MainActor in
                    self?.errorKey = "notification.deliveryError"; self?.errorDetail = nil; self?.onChange?()
                }
            }
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
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
