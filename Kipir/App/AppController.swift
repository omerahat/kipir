import AppKit
import SwiftUI
import ServiceManagement

@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()
    let engine: BreakScheduler
    let notifications = NotificationManager()
    private let store = LocalStore()
    private let activity = ActivityMonitor()
    private var heartbeat: Timer?
    private let breakSound = NSSound(named: "Tink")
    private var lastSave: TimeInterval = 0
    @Published private(set) var revision = 0
    @Published private(set) var settings: Settings
    @Published private(set) var loginEnabled = false
    @Published private(set) var loginMessage: String?
    /// Transient line under the timer (completed break / natural break); expires from the heartbeat.
    @Published private(set) var notice: TransientNotice?
    /// Set by the app delegate; a notification click asks the status bar to show the main popover.
    var onOpenRequest: (() -> Void)?
    /// Stored in UserDefaults; the setter publishes explicitly because `@AppStorage` inside an
    /// `ObservableObject` does not.
    var onboarded: Bool {
        get { UserDefaults.standard.bool(forKey: "onboarded") }
        set { objectWillChange.send(); UserDefaults.standard.set(newValue, forKey: "onboarded") }
    }

    /// Stored choice: "system", "tr" or "en". A missing key means "system" (DECISIONS 029).
    var languagePreference: String {
        AppLanguage.normalizedPreference(UserDefaults.standard.string(forKey: "language"))
    }
    /// Language actually shown ("tr" or "en").
    var language: String { currentLanguage() }
    func setLanguage(_ value: String) {
        guard value == "system" || AppLanguage.supported.contains(value), value != languagePreference else { return }
        if value == "system" { UserDefaults.standard.removeObject(forKey: "language") }
        else { UserDefaults.standard.set(value, forKey: "language") }
        notifications.updateLanguage()
        if loginMessage != nil {
            loginMessage = L(SMAppService.mainApp.status == .requiresApproval ? "login.approval" : "login.error")
        }
        revision &+= 1
    }

    private init() {
        let settings = store.loadSettings()
        self.settings = settings
        engine = BreakScheduler(settings: settings, checkpoint: store.loadCheckpoint(),
                                now: { ProcessInfo.processInfo.systemUptime }, date: Date.init,
                                idle: { ActivityMonitor.idleSeconds() })
        activity.onSuspension = { [weak self] value in
            guard let self else { return }
            self.engine.setSuspended(value); self.publish(save: true)
        }
        notifications.onAction = { [weak self] id, action in
            guard let self, self.engine.reminderID == id else { return }
            self.perform(action)
        }
        notifications.onChange = { [weak self] in self?.revision &+= 1 }
        notifications.onOpen = { [weak self] in self?.onOpenRequest?() }
        refreshLogin()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        heartbeat = timer
        publish()
    }
    func tick() {
        let before = engine.checkpoint
        engine.tick()
        let after = engine.checkpoint
        let now = ProcessInfo.processInfo.systemUptime
        // Persist every reset or episode change at once: natural-break and window-entry resets are
        // working -> working, so a phase comparison alone would miss them.
        let changed = before.phase != after.phase || before.meeting != after.meeting
            || after.activeWork < before.activeWork || before.dueID != after.dueID
            || before.wasOffHours != after.wasOffHours
        publish(save: changed || now - lastSave >= 15)
    }
    func perform(_ action: SchedulerAction) { engine.perform(action); publish(save: true) }
    func changeSettings(_ change: (inout Settings) -> Void) {
        var value = settings; change(&value); settings = value.validated()
        engine.updateSettings(settings); store.save(settings); publish(save: true)
    }
    func setMeeting(_ enabled: Bool, minutes: Int? = nil) {
        engine.setMeeting(enabled, duration: minutes.map { Double($0) * 60 })
        publish(save: true)
    }
    /// The popover actually displayed the notice row: its short visible lifetime starts now.
    func noticeDisplayed() {
        guard let notice, notice.isPending else { return }
        let next = notice.markingDisplayed(at: ProcessInfo.processInfo.systemUptime)
        if next != self.notice { self.notice = next }
    }
    func navigateExercise(_ offset: Int) { engine.navigateExercise(offset); publish(save: true) }
    func save() { engine.tick(); publish(save: true) }
    private func publish(save: Bool = false) {
        // One consumption feeds both the sound and the notice; skips and manual finishes yield neither.
        let now = ProcessInfo.processInfo.systemUptime
        let outcome = BreakCompletionFeedback.consume(from: engine) {
            breakSound?.volume = 0.25
            breakSound?.play()
        }
        let naturalBreak = engine.consumeNaturalBreak()
        let next = TransientNotice.next(current: notice, outcome: outcome, naturalBreak: naturalBreak, todayBreaks: engine.today.breaks, now: now)
        if next != notice { notice = next }
        if save { store.save(engine.checkpoint); lastSave = now }
        notifications.sync(engine: engine)
        revision &+= 1
    }
    var notificationState: NotificationEffectiveState {
        notifications.effectiveState(enabled: settings.notifications)
    }
    /// Explicit user click: request permission or open System Settings, whichever the current state offers.
    func performNotificationAction() { notifications.perform(notificationState.primaryAction) }
    func testNotification() {
        Task { await notifications.testNotification(enabled: { self.settings.notifications }, sound: settings.sound) }
    }
    func refreshSystemSettings() {
        refreshLogin()
        Task { await notifications.refreshPermission() }
    }
    private func refreshLogin() {
        loginEnabled = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval { loginMessage = L("login.approval") }
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginMessage = nil
        } catch { loginMessage = L("login.error") }
        refreshLogin()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusBar: StatusBarController?
    /// Runs before launch completes so the notification delegate exists when a click launches the app; an open
    /// request that arrives before the status item is installed is queued by `StatusBarController`.
    func applicationWillFinishLaunching(_ notification: Notification) {
        let controller = AppController.shared
        let statusBar = StatusBarController(controller: controller)
        controller.onOpenRequest = { [weak statusBar] in statusBar?.requestOpen() }
        self.statusBar = statusBar
    }
    func applicationDidFinishLaunching(_ notification: Notification) { statusBar?.install() }
    func applicationWillTerminate(_ notification: Notification) { AppController.shared.save() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
