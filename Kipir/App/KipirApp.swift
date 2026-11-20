import SwiftUI

/// The menu bar item, popover and Settings window are AppKit-owned (`StatusBarController`): SwiftUI's
/// `MenuBarExtra` offers no stable label geometry, no programmatic presentation and no appearance control for its
/// window. The empty Settings scene only satisfies `App`; its menu command opens Kıpır's own Settings window.
@main
struct KipirApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        SwiftUI.Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button(L("settings")) { delegate.statusBar?.openSettings() }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}
