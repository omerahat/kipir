import AppKit
import CoreGraphics

@MainActor
final class ActivityMonitor {
    private var workspaceTokens: [NSObjectProtocol] = []
    private var distributedTokens: [NSObjectProtocol] = []
    private var reasons: Set<String> = []
    var onSuspension: ((Bool) -> Void)?

    static func idleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                               eventType: CGEventType(rawValue: UInt32.max)!)
    }
    init() {
        let center = NSWorkspace.shared.notificationCenter
        let pairs: [(Notification.Name, Notification.Name, String)] = [
            (NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification, "sleep"),
            (NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification, "session"),
            (NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification, "display")
        ]
        for (off, on, reason) in pairs {
            workspaceTokens.append(center.addObserver(forName: off, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.set(reason, suspended: true) }
            })
            workspaceTokens.append(center.addObserver(forName: on, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.set(reason, suspended: false) }
            })
        }
        // These lock hints supplement workspace/session events; unknown heartbeat gaps also fail closed.
        let distributed = DistributedNotificationCenter.default()
        for (name, suspended) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            distributedTokens.append(distributed.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.set("lock", suspended: suspended) }
            })
        }
    }
    private func set(_ reason: String, suspended: Bool) {
        if suspended { reasons.insert(reason) } else { reasons.remove(reason) }
        onSuspension?(!reasons.isEmpty)
    }
}
