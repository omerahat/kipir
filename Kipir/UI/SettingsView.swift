import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var controller: AppController
    private func binding<T>(_ key: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(get: { controller.settings[keyPath: key] }, set: { value in controller.changeSettings { $0[keyPath: key] = value } })
    }
    private func minutes(_ key: WritableKeyPath<Settings, Double>) -> Binding<Double> {
        Binding(get: { controller.settings[keyPath: key] / 60 }, set: { value in controller.changeSettings { $0[keyPath: key] = value * 60 } })
    }
    var body: some View {
        Form {
            Section(L("settings.timing")) {
                Picker(L("preset.title"), selection: Binding(
                    get: { TimingPreset.match(controller.settings)?.rawValue ?? "custom" },
                    set: { value in
                        if let preset = TimingPreset(rawValue: value) {
                            controller.changeSettings { preset.apply(to: &$0) }
                        }
                    })) {
                    Text(L("preset.quick")).tag("quick")
                    Text(L("preset.balanced")).tag("balanced")
                    Text(L("preset.custom")).tag("custom").disabled(true)
                }.pickerStyle(.segmented)
                Stepper(value: minutes(\.work), in: 1...240, step: 1) { valueLabel("setting.work", controller.settings.work / 60, "unit.minutes") }
                Stepper(value: binding(\.shortBreak), in: 10...1800, step: 10) { valueLabel("setting.short", controller.settings.shortBreak, "unit.seconds") }
                Stepper(value: binding(\.longBreak), in: 10...3600, step: 10) { valueLabel("setting.long", controller.settings.longBreak, "unit.seconds") }
                Stepper(value: binding(\.longEvery), in: 1...10) { Text(L("setting.frequency") + ": \(controller.settings.longEvery)") }
                Stepper(value: binding(\.afk), in: 15...600, step: 15) { valueLabel("setting.afk", controller.settings.afk, "unit.seconds") }
                Stepper(value: minutes(\.snooze), in: 1...60, step: 1) { valueLabel("setting.snooze", controller.settings.snooze / 60, "unit.minutes") }
                Toggle(L("setting.breakEndSound"), isOn: binding(\.breakEndSound))
                Text(L("settings.accounting")).font(.caption).foregroundStyle(.secondary)
            }
            Section(L("settings.notifications")) {
                Toggle(L("setting.notifications"), isOn: binding(\.notifications))
                Toggle(L("setting.sound"), isOn: binding(\.sound)).disabled(!controller.settings.notifications)
                Text(controller.notifications.permissionText).font(.caption)
                    .foregroundStyle(controller.notifications.authorized && !controller.notifications.capabilities.canShowDesktopAlerts ? Color.orange : Color.secondary)
                if controller.notifications.authorized {
                    Text(controller.notifications.deliveryDetailsText).font(.caption).foregroundStyle(.secondary)
                }
                Button(L("notification.settings.open")) { controller.notifications.openNotificationSettings() }
                if let key = controller.notifications.settingsNavigationKey {
                    Text(L(key)).font(.caption).foregroundStyle(.secondary)
                }
                Button(L("permission.request")) { controller.notifications.requestPermission() }
                Button(L("notification.test.button")) { controller.testNotification() }
                    .disabled(controller.notifications.testing)
                if let key = controller.notifications.testResultKey {
                    Text(L(key)).font(.caption).foregroundStyle(.secondary)
                }
                if let error = controller.notifications.errorText { Text(error).foregroundStyle(.red).font(.caption).textSelection(.enabled) }
            }
            Section(L("settings.general")) {
                Picker(L("setting.language"), selection: Binding(get: { controller.language }, set: { controller.setLanguage($0) })) {
                    Text(verbatim: "Türkçe").tag("tr")
                    Text(verbatim: "English").tag("en")
                }
                Picker(L("setting.appearance"), selection: binding(\.appearance)) {
                    Text(L("appearance.system")).tag("system")
                    Text(L("appearance.light")).tag("light")
                    Text(L("appearance.dark")).tag("dark")
                }
                Toggle(L("setting.login"), isOn: Binding(get: { controller.loginEnabled }, set: { controller.setLogin($0) }))
                if let message = controller.loginMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                Text(L("privacy.summary")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped).frame(width: 480, height: 640)
        .navigationTitle(L("settings.title"))
        .onAppear { controller.refreshSystemSettings() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            controller.refreshSystemSettings()
        }
    }
    private func valueLabel(_ key: String, _ value: Double, _ unit: String) -> some View {
        Text(L(key) + ": \(Int(value)) " + L(unit))
    }
}
