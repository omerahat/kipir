import AppKit
import Combine
import SwiftUI

/// Owns the menu bar item, the main popover and the Settings window (pre-release Fixes 2, 4 and 5).
///
/// - The status item shows one fixed-size template image (icon slot + text slot measured over every label in
///   every language), so state, countdown or language changes never change its width or move the popover anchor.
/// - The popover is the single presentation path: a click on the item and a click on a delivered notification
///   both call `showPopover()`. Requests that arrive before the item exists are queued, not dropped.
/// - Appearance is applied from `Settings.appearance` to the popover and the Settings window together.
@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let controller: AppController
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var pendingOpen = false
    private var lastClose: TimeInterval = -1
    private var textSlot: CGFloat = 0
    private var labelKey: String?
    private var subscription: AnyCancellable?
    private var appearanceObservation: NSKeyValueObservation?

    init(controller: AppController) {
        self.controller = controller
        super.init()
    }

    func install() {
        guard item == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.imagePosition = .imageOnly
        self.item = item
        textSlot = Self.measureTextSlot()
        popover.behavior = .transient
        popover.delegate = self
        // Deferred one turn so the sink reads state after `revision` (a willSet publisher) has been stored.
        subscription = controller.$revision.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.refresh() }
        // System appearance changes (Light ↔ Dark in System Settings) re-resolve the "System" choice.
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            let target = self
            DispatchQueue.main.async { target?.applyAppearance() }
        }
        refresh()
        if pendingOpen { pendingOpen = false; showPopover() }
    }

    // MARK: Popover

    /// Entry point for notification clicks: always ends with the popover visible, never toggles it closed.
    func requestOpen() {
        guard item?.button != nil else { pendingOpen = true; return }
        showPopover()
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if popover.isShown { popover.performClose(sender); return }
        // A transient popover closes on the same mouse-down that hits the item; don't reopen it immediately.
        if ProcessInfo.processInfo.systemUptime - lastClose < 0.3 { return }
        showPopover()
    }

    private func showPopover() {
        guard let button = item?.button else { pendingOpen = true; return }
        NSApp.activate(ignoringOtherApps: true)
        if popover.isShown {
            popover.contentViewController?.view.window?.makeKey()
            return
        }
        // A fresh hosting controller per presentation keeps `.onAppear` meaning "the panel was opened",
        // which the notice lifetime and the permission refresh rely on.
        let host = NSHostingController(rootView: PopoverRoot(controller: controller, openSettings: { [weak self] in
            self?.openSettings()
        }))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        applyAppearance()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        button.highlight(true)
    }

    func popoverDidClose(_ notification: Notification) {
        lastClose = ProcessInfo.processInfo.systemUptime
        item?.button?.highlight(false)
        popover.contentViewController = nil
    }

    // MARK: Settings window

    func openSettings() {
        if popover.isShown { popover.performClose(nil) }
        let window: NSWindow
        if let existing = settingsWindow {
            window = existing
        } else {
            let host = NSHostingController(rootView: SettingsRoot(controller: controller))
            window = NSWindow(contentViewController: host)
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            if !window.setFrameUsingName("KipirSettings") { window.center() }
            window.setFrameAutosaveName("KipirSettings")
            settingsWindow = window
        }
        window.title = L("settings.title")
        applyAppearance()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: State propagation

    private func refresh() {
        applyAppearance()
        settingsWindow?.title = L("settings.title")
        renderLabel()
    }

    /// One preference source for every Kıpır surface. "System" resolves the system appearance explicitly for the
    /// popover: left unset, a popover inherits the menu bar's appearance, which can be dark in light mode.
    private func applyAppearance() {
        let forced = Self.appearance(for: controller.settings.appearance)
        let systemIsDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let popoverName: NSAppearance.Name = forced?.name ?? (systemIsDark ? .darkAqua : .aqua)
        // Assigned only on change: this runs on every heartbeat publish.
        if let window = settingsWindow, window.appearance?.name != forced?.name { window.appearance = forced }
        if popover.appearance?.name != popoverName { popover.appearance = NSAppearance(named: popoverName) }
    }

    static func appearance(for setting: String) -> NSAppearance? {
        switch setting {
        case "light": return NSAppearance(named: .aqua)
        case "dark": return NSAppearance(named: .darkAqua)
        default: return nil
        }
    }

    // MARK: Menu bar label

    static var labelFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
    }

    private static func measureTextSlot() -> CGFloat {
        let tables = AppLanguage.supported.compactMap { language -> [String: String]? in
            guard let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil,
                                              forLocalization: language) else { return nil }
            return NSDictionary(contentsOfFile: path) as? [String: String]
        }
        let font = labelFont
        return CGFloat(MenuBarLabelLayout.textSlotWidth(candidates: MenuBarLabelLayout.candidates(tables: tables)) {
            Double(($0 as NSString).size(withAttributes: [.font: font]).width)
        })
    }

    private func renderLabel() {
        guard let button = item?.button else { return }
        let engine = controller.engine
        let status = MenuBarStatusFormatter(status: engine.status, remaining: engine.remaining,
                                            iconOnly: controller.settings.menuBarStyle == "icon",
                                            breakDue: engine.checkpoint.phase == .due)
        let text = status.showsText ? status.text(L) : nil
        let summary = status.summary(L)
        let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        let key = [status.symbol, text ?? "", "\(textSlot)", "\(scale)"].joined(separator: "|")
        if key != labelKey {
            labelKey = key
            button.image = StatusLabelImage.make(symbol: status.symbol, text: text, textSlot: textSlot,
                                                  font: Self.labelFont, scale: max(2, scale))
        }
        if button.toolTip != summary {
            button.toolTip = summary
            button.setAccessibilityLabel(summary)
        }
    }
}

/// Popover content. Observes the controller so the locale follows language changes while the panel is open.
private struct PopoverRoot: View {
    @ObservedObject var controller: AppController
    let openSettings: () -> Void
    var body: some View {
        MenuBarView(controller: controller, openSettings: openSettings)
            .environment(\.locale, Locale(identifier: controller.language))
    }
}

private struct SettingsRoot: View {
    @ObservedObject var controller: AppController
    var body: some View {
        SettingsView(controller: controller)
            .environment(\.locale, Locale(identifier: controller.language))
    }
}
