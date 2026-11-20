import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var controller: AppController
    @State private var showDiagnostics = false
    private var locale: Locale { Locale(identifier: controller.language) }
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = locale
        return calendar
    }
    private func binding<T>(_ key: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(get: { controller.settings[keyPath: key] }, set: { value in controller.changeSettings { $0[keyPath: key] = value } })
    }
    private func minutes(_ key: WritableKeyPath<Settings, Double>) -> Binding<Double> {
        Binding(get: { controller.settings[keyPath: key] / 60 }, set: { value in controller.changeSettings { $0[keyPath: key] = value * 60 } })
    }
    var body: some View {
        Form {
            timingSection
            breaksSection
            workingHoursSection
            notificationsSection
            generalSection
        }
        .formStyle(.grouped).frame(width: 480, height: 640)
        .navigationTitle(L("settings.title"))
        .onAppear { controller.refreshSystemSettings() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            controller.refreshSystemSettings()
        }
    }

    // MARK: Timing

    private var timingSection: some View {
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
            durationPicker("setting.short", \.shortBreak, BreakDurationOptions.short)
            durationPicker("setting.long", \.longBreak, BreakDurationOptions.long)
            Stepper(value: binding(\.longEvery), in: 1...10) { Text(L("setting.frequency") + ": \(controller.settings.longEvery)") }
            Stepper(value: binding(\.afk), in: 15...600, step: 15) { valueLabel("setting.afk", controller.settings.afk, "unit.seconds") }
            Stepper(value: minutes(\.snooze), in: 1...60, step: 1) { valueLabel("setting.snooze", controller.settings.snooze / 60, "unit.minutes") }
            Toggle(L("setting.breakEndSound"), isOn: binding(\.breakEndSound))
            Text(L("settings.accounting")).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let label = BreakDurationOptions.label(seconds)
        return String(format: L(label.key), arguments: label.values.map { $0 as CVarArg })
    }

    /// Preset picker over stored seconds. A stored non-preset value gets an extra "Custom" row so the picker
    /// is never blank; nothing is written until the user picks a preset.
    private func durationPicker(_ titleKey: String, _ key: WritableKeyPath<Settings, Double>, _ options: [TimeInterval]) -> some View {
        let current = controller.settings[keyPath: key]
        return Picker(L(titleKey), selection: binding(key)) {
            if !BreakDurationOptions.isPreset(current, in: options) {
                Text(String(format: L("ui.duration.custom"), durationText(current))).tag(current).disabled(true)
            }
            ForEach(options, id: \.self) { Text(durationText($0)).tag($0) }
        }
    }

    // MARK: Breaks and exercises

    private var breaksSection: some View {
        Section(L("ui.settings.breaks")) {
            Picker(L("ui.naturalBreak.title"), selection: binding(\.naturalBreak)) {
                ForEach(Settings.naturalBreakOptions, id: \.self) { value in
                    Text(value == 0 ? L("ui.naturalBreak.off") : durationText(value)).tag(value)
                }
            }
            Text(L("ui.naturalBreak.note")).font(.caption).foregroundStyle(.secondary)
            if controller.settings.naturalBreakIsRaised {
                Text(String(format: L("ui.naturalBreak.effective"), controller.settings.effectiveNaturalBreakMinutes))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Picker(L("ui.focus.title"), selection: binding(\.exerciseFocus)) {
                Text(L("ui.focus.all")).tag(ExerciseFocus.all.rawValue)
                Text(L("ui.focus.neckShoulders")).tag(ExerciseFocus.neckShoulders.rawValue)
                Text(L("ui.focus.back")).tag(ExerciseFocus.back.rawValue)
                Text(L("ui.focus.hands")).tag(ExerciseFocus.hands.rawValue)
            }
        }
    }

    // MARK: Working hours

    private var workingHoursSection: some View {
        let hours = controller.settings.workingHours
        return Section(L("ui.hours.section")) {
            Toggle(L("ui.hours.enable"), isOn: hoursBinding(get: { $0.enabled }, set: { $0.enabled = $1 }))
            if hours.enabled {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(L("ui.hours.days")).font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: Space.xs) {
                        ForEach(WorkingHoursEditing.orderedWeekdays(calendar: calendar), id: \.self) { day in
                            Toggle(WorkingHoursEditing.weekdayName(day, locale: locale, short: true),
                                   isOn: Binding(get: { hours.weekdays.contains(day) },
                                                 set: { _ in
                                                     controller.changeSettings {
                                                         $0.workingHours.weekdays = WorkingHoursEditing.toggling(day, in: $0.workingHours.weekdays)
                                                     }
                                                 }))
                                .toggleStyle(.button).controlSize(.small).lineLimit(1)
                                .accessibilityLabel(WorkingHoursEditing.weekdayName(day, locale: locale, short: false))
                        }
                    }
                }
                DatePicker(L("ui.hours.start"), selection: timeBinding(\.start), displayedComponents: .hourAndMinute)
                DatePicker(L("ui.hours.end"), selection: timeBinding(\.end), displayedComponents: .hourAndMinute)
                if WorkingHoursEditing.crossesMidnight(hours) {
                    Text(L("ui.hours.overnight")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(L("ui.hours.note")).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func hoursBinding<T>(get: @escaping (WorkingHours) -> T, set: @escaping (inout WorkingHours, T) -> Void) -> Binding<T> {
        Binding(get: { get(controller.settings.workingHours) },
                set: { value in controller.changeSettings { set(&$0.workingHours, value) } })
    }
    private func timeBinding(_ key: WritableKeyPath<WorkingHours, Int>) -> Binding<Date> {
        Binding(get: { WorkingHoursEditing.date(forMinutes: controller.settings.workingHours[keyPath: key], calendar: calendar) },
                set: { date in
                    let value = WorkingHoursEditing.minutes(of: date, calendar: calendar)
                    controller.changeSettings {
                        $0.workingHours = key == \WorkingHours.start
                            ? WorkingHoursEditing.updating($0.workingHours, start: value)
                            : WorkingHoursEditing.updating($0.workingHours, end: value)
                    }
                })
    }

    // MARK: Notifications

    private var notificationsSection: some View {
        let state = controller.notificationState
        let manager = controller.notifications
        return Section(L("settings.notifications")) {
            Toggle(L("setting.notifications"), isOn: binding(\.notifications))
            Toggle(L("setting.sound"), isOn: binding(\.sound)).disabled(!controller.settings.notifications)
            Label(L(state.statusKey), systemImage: state.symbol)
                .foregroundStyle(state.needsAttention ? Color.orange : Color.secondary)
            switch state.primaryAction {
            case .requestPermission:
                Button(L("permission.request")) { controller.performNotificationAction() }
                    .buttonStyle(.borderedProminent).tint(.teal)
            case .openSettings:
                Button(L("notification.settings.open")) { controller.performNotificationAction() }
                    .buttonStyle(.borderedProminent).tint(.teal)
            case .none: EmptyView()
            }
            if let error = manager.errorText { Text(error).foregroundStyle(.red).font(.caption).textSelection(.enabled) }
            DisclosureGroup(L("ui.notif.diagnostics"), isExpanded: $showDiagnostics) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(manager.permissionText).font(.caption)
                        .foregroundStyle(manager.authorized && !manager.capabilities.canShowDesktopAlerts ? Color.orange : Color.secondary)
                    if manager.authorized {
                        Text(manager.deliveryDetailsText).font(.caption).foregroundStyle(.secondary)
                    }
                    if state.primaryAction != .openSettings {
                        Button(L("notification.settings.open")) { manager.openNotificationSettings() }
                    }
                    if let key = manager.settingsNavigationKey {
                        Text(L(key)).font(.caption).foregroundStyle(.secondary)
                    }
                    Button(L("notification.test.button")) { controller.testNotification() }
                        .disabled(manager.testing)
                    if let key = manager.testResultKey {
                        Text(L(key)).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.top, Space.xs)
            }
        }
    }

    // MARK: General

    private var generalSection: some View {
        Section(L("settings.general")) {
            Picker(L("setting.language"), selection: Binding(get: { controller.languagePreference }, set: { controller.setLanguage($0) })) {
                Text(L("language.system")).tag("system")
                Text(verbatim: "Türkçe").tag("tr")
                Text(verbatim: "English").tag("en")
            }
            Picker(L("setting.appearance"), selection: binding(\.appearance)) {
                Text(L("appearance.system")).tag("system")
                Text(L("appearance.light")).tag("light")
                Text(L("appearance.dark")).tag("dark")
            }
            Picker(L("ui.setting.menuBarStyle"), selection: binding(\.menuBarStyle)) {
                Text(L("ui.menuBarStyle.timer")).tag("timer")
                Text(L("ui.menuBarStyle.icon")).tag("icon")
            }
            Toggle(L("setting.login"), isOn: Binding(get: { controller.loginEnabled }, set: { controller.setLogin($0) }))
            if let message = controller.loginMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
            Text(L("privacy.summary")).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func valueLabel(_ key: String, _ value: Double, _ unit: String) -> some View {
        Text(L(key) + ": \(Int(value)) " + L(unit))
    }
}
