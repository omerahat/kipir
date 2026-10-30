import SwiftUI

@main
struct KipirApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var controller = AppController.shared
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(controller: controller).preferredColorScheme(controller.colorScheme)
        } label: {
            Image(systemName: controller.engine.status == .due ? "figure.walk.circle.fill" : "figure.walk")
                .accessibilityLabel(L("app.name") + ", " + L("status." + controller.engine.status.rawValue))
        }
        .menuBarExtraStyle(.window)
        SwiftUI.Settings {
            SettingsView(controller: controller).preferredColorScheme(controller.colorScheme)
        }
    }
}
