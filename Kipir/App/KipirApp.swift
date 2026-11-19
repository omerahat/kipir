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
            let status = MenuBarStatusFormatter(status: controller.engine.status, remaining: controller.engine.remaining,
                                                iconOnly: controller.settings.menuBarStyle == "icon")
            let summary = status.summary(L)
            Group {
                if status.showsText, let key = status.textKey {
                    Label {
                        // Only the minute countdown reserves width (avoids jitter); other labels size to content.
                        Text(String(format: L(key), status.minutes)).monospacedDigit()
                            .frame(minWidth: key == "menubar.minutes" ? 64 : nil, alignment: .leading)
                    } icon: { Image(systemName: status.symbol) }
                    .labelStyle(.titleAndIcon)
                } else {
                    Image(systemName: status.symbol)
                }
            }
            .help(summary)
            .accessibilityLabel(summary)
        }
        .menuBarExtraStyle(.window)
        SwiftUI.Settings {
            SettingsView(controller: controller).preferredColorScheme(controller.colorScheme)
                .environment(\.locale, Locale(identifier: controller.language))
        }
    }
}
