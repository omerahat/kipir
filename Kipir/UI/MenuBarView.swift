import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var controller: AppController
    @State private var confirmReset = false
    private var engine: BreakScheduler { controller.engine }
    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Image(systemName: "figure.walk").font(.title2).foregroundStyle(.teal)
                Text(L("app.name")).font(.title3.bold())
                Spacer()
                Text(L("status." + engine.status.rawValue))
                    .font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.teal.opacity(0.12), in: Capsule())
            }
            if !controller.onboarded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("welcome.title")).font(.headline)
                    Text(L("welcome.body")).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(L("permission.request")) { controller.notifications.requestPermission() }
                        Spacer()
                        Button(L("welcome.done")) { controller.onboarded = true }
                    }
                }.padding(12).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
            ZStack {
                Circle().stroke(.teal.opacity(0.12), lineWidth: 8)
                Circle().trim(from: 0, to: engine.progress)
                    .stroke(.teal, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 6) {
                    Text(durationText(engine.remaining)).font(.system(size: 38, weight: .medium, design: .rounded)).monospacedDigit()
                    Text(L(engine.checkpoint.phase == .onBreak ? "timer.break" : "timer.untilBreak"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 174, height: 174)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L(engine.checkpoint.phase == .onBreak ? "timer.break" : "timer.untilBreak"))
            .accessibilityValue(durationText(engine.remaining))
            VStack(spacing: 4) {
                Text(L(engine.nextBreakIsLong ? "next.long" : "next.short")).font(.subheadline.weight(.medium))
                Text(L("timer.confirmed") + " " + durationText(engine.activeWork))
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button { controller.perform(.togglePause) } label: {
                    Label(L(engine.paused ? "resume" : "pause"), systemImage: engine.paused ? "play.fill" : "pause.fill")
                }
                if engine.checkpoint.phase != .onBreak {
                    Button(L("break.start")) { controller.perform(.startBreak) }
                        .buttonStyle(.borderedProminent).tint(.teal)
                        .disabled(engine.paused || engine.meeting || engine.suspended)
                } else {
                    Button(L("break.end")) { controller.perform(.skip) }
                }
            }.controlSize(.large)
            if engine.status == .due {
                HStack {
                    Button(L("snooze")) { controller.perform(.snooze) }
                    Button(L("skip")) { controller.perform(.skip) }
                }
            }
            Toggle(isOn: Binding(get: { engine.meeting }, set: { _ in controller.perform(.toggleMeeting) })) {
                Label(L("meeting"), systemImage: "person.2")
            }.toggleStyle(.switch)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("today.title")).font(.caption).foregroundStyle(.secondary)
                    Text(durationText(engine.today.activeSeconds)).font(.headline).monospacedDigit()
                    Text(L("today.active")).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(engine.today.breaks)").font(.title2.weight(.semibold))
                    Text(L("today.breaks")).font(.caption2).foregroundStyle(.secondary)
                }
            }.padding(14).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            Divider()
            HStack {
                SettingsLink { Label(L("settings"), systemImage: "gearshape") }
                    .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })
                Spacer()
                Menu {
                    Button(L("session.reset")) { confirmReset = true }
                    Button(L("quit")) { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis.circle").accessibilityLabel(L("more")) }
                .menuStyle(.borderlessButton).fixedSize()
            }.font(.caption)
        }
        .padding(20).frame(width: 330)
        .alert(L("session.reset"), isPresented: $confirmReset) {
            Button(L("cancel"), role: .cancel) {}
            Button(L("session.reset"), role: .destructive) { controller.perform(.reset) }
        } message: { Text(L("session.resetMessage")) }
        .onAppear { controller.tick(); controller.refreshSystemSettings() }
    }
}
