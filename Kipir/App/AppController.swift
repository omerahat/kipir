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
    @AppStorage("onboarded") var onboarded = false

    var language: String {
        UserDefaults.standard.string(forKey: "language") == "en" ? "en" : "tr"
    }
    func setLanguage(_ value: String) {
        guard ["tr", "en"].contains(value), value != language else { return }
        UserDefaults.standard.set(value, forKey: "language")
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
        let oldPhase = engine.checkpoint.phase
        let oldMeeting = engine.meeting
        engine.tick()
        let now = ProcessInfo.processInfo.systemUptime
        publish(save: oldPhase != engine.checkpoint.phase || oldMeeting != engine.meeting || now - lastSave >= 15)
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
    func navigateExercise(_ offset: Int) { engine.navigateExercise(offset); publish(save: true) }
    func save() { engine.tick(); publish(save: true) }
    private func publish(save: Bool = false) {
        BreakCompletionFeedback.consume(from: engine) {
            breakSound?.volume = 0.25
            breakSound?.play()
        }
        if save { store.save(engine.checkpoint); lastSave = ProcessInfo.processInfo.systemUptime }
        notifications.sync(engine: engine)
        revision &+= 1
    }
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
    var colorScheme: ColorScheme? {
        settings.appearance == "light" ? .light : settings.appearance == "dark" ? .dark : nil
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) { AppController.shared.save() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
