import SwiftUI

@main
struct KipirApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var controller = AppController.shared
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller).preferredColorScheme(controller.colorScheme)
                .environment(\.locale, Locale(identifier: controller.language))
        } label: {
            let status = MenuBarStatusFormatter(status: controller.engine.status, remaining: controller.engine.remaining)
            Label {
                if let key = status.textKey {
                    Text(String(format: L(key), status.minutes)).monospacedDigit()
                        .frame(minWidth: 64, alignment: .leading)
                }
            } icon: { Image(systemName: status.symbol) }
            .labelStyle(.titleAndIcon)
            .accessibilityLabel(L("app.name") + ", " + L("status." + controller.engine.status.rawValue)
                + ", " + String(format: L("menubar.minutes"), status.minutes))
        }
        .menuBarExtraStyle(.window)
        SwiftUI.Settings {
            SettingsView(controller: controller).preferredColorScheme(controller.colorScheme)
                .environment(\.locale, Locale(identifier: controller.language))
        }
    }
}
