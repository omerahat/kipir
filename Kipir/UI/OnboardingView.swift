import SwiftUI

/// First-run welcome inside the popover: two short steps, no window, no automatic permission request.
/// Users with `onboarded` already stored never see it (the key is shared with `AppController`).
struct OnboardingView: View {
    @ObservedObject var controller: AppController
    @State private var step = 0

    private func row(_ symbol: String, _ key: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(.teal).frame(width: 20).accessibilityHidden(true)
            Text(L(key)).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if step == 0 {
                Text(L("ui.onboarding.title")).font(.headline)
                row("menubar.rectangle", "ui.onboarding.menubar")
                row("timer", "ui.onboarding.timing")
                row("lock.shield", "ui.onboarding.local")
                HStack {
                    Spacer()
                    Button(L("ui.onboarding.next")) { step = 1 }.buttonStyle(.borderedProminent).tint(.teal)
                }
            } else {
                Text(L("ui.onboarding.notif.title")).font(.headline)
                Text(L("ui.onboarding.notif.body")).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                let state = controller.notifications.effectiveState(enabled: true)
                if state == .active {
                    Label(L("ui.onboarding.notif.done"), systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
                } else if state.primaryAction != .none {
                    // Explicit click only; denied permission opens System Settings instead of re-prompting.
                    Button(L(state.primaryAction == .requestPermission ? "permission.request" : "notification.settings.open")) {
                        controller.notifications.perform(state.primaryAction)
                    }
                }
                HStack {
                    Spacer()
                    Button(L("welcome.done")) { controller.onboarded = true }
                        .buttonStyle(.borderedProminent).tint(.teal)
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }
}
