import SwiftUI
import AppKit

/// Spacing scale shared by the popover and Settings.
enum Space {
    static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24
}

struct MenuBarView: View {
    @ObservedObject var controller: AppController
    @State private var confirmReset = false
    private var engine: BreakScheduler { controller.engine }
    var body: some View {
        VStack(spacing: Space.l) {
            HStack(spacing: Space.s) {
                Image(systemName: "figure.walk").font(.title2).foregroundStyle(.teal).accessibilityHidden(true)
                Text(L("app.name")).font(.title3.bold())
                Spacer()
                Text(L("status." + engine.status.rawValue))
                    .font(.caption.weight(.medium)).padding(.horizontal, Space.s + 2).padding(.vertical, Space.xs + 1)
                    .background(.teal.opacity(0.12), in: Capsule())
            }
            if !controller.onboarded { OnboardingView(controller: controller) }
            if let note = statusNote {
                Text(note).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
            }
            if engine.checkpoint.phase == .onBreak {
                BreakExerciseView(controller: controller)
            } else {
                ZStack {
                    Circle().stroke(.teal.opacity(0.12), lineWidth: 8)
                    Circle().trim(from: 0, to: engine.progress)
                        .stroke(.teal, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                    VStack(spacing: Space.xs) {
                        Text(durationText(engine.remaining)).font(.system(size: 38, weight: .medium, design: .rounded)).monospacedDigit()
                        Text(L("timer.untilBreak")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 174, height: 174)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L("timer.untilBreak"))
                .accessibilityValue(durationText(engine.remaining))
                VStack(spacing: Space.xs) {
                    Text(L(engine.nextBreakIsLong ? "next.long" : "next.short")).font(.subheadline.weight(.medium))
                    Text(L("timer.confirmed") + " " + durationText(engine.activeWork))
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: Space.s) {
                    Button { controller.perform(.togglePause) } label: {
                        Label(L(engine.paused ? "resume" : "pause"), systemImage: engine.paused ? "play.fill" : "pause.fill")
                    }
                    // The break action is the single prominent control, and only when a break is due.
                    if engine.status == .due {
                        Button(L("break.start")) { controller.perform(.startBreak) }
                            .buttonStyle(.borderedProminent).tint(.teal)
                    } else {
                        Button(L("break.start")) { controller.perform(.startBreak) }
                            .disabled(engine.paused || engine.meeting || engine.suspended)
                    }
                }.controlSize(.large)
                if engine.status == .due {
                    HStack(spacing: Space.s) {
                        Button(L("snooze")) { controller.perform(.snooze) }
                        Button(L("skip")) { controller.perform(.skip) }
                    }
                }
                if let notice = controller.notice { noticeView(notice) }
                HStack {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(L("today.title")).font(.caption).foregroundStyle(.secondary)
                        Text(durationText(engine.today.activeSeconds)).font(.headline).monospacedDigit()
                        Text(L("today.active")).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: Space.xs) {
                        Text("\(engine.today.breaks)").font(.title2.weight(.semibold))
                        Text(L("today.breaks")).font(.caption2).foregroundStyle(.secondary)
                    }
                }.padding(Space.m).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
            HStack(spacing: Space.s) {
                Toggle(isOn: Binding(get: { engine.meeting }, set: { controller.setMeeting($0) })) {
                    Label(L("meeting"), systemImage: "person.2")
                }.toggleStyle(.switch)
                Menu {
                    ForEach([15, 30, 60], id: \.self) { minutes in
                        Button(String(format: L("menubar.minutes"), minutes)) { controller.setMeeting(true, minutes: minutes) }
                    }
                    Button(L("meeting.indefinite")) { controller.setMeeting(true) }
                } label: { Image(systemName: "clock").accessibilityLabel(L("meeting.duration")) }
                .menuStyle(.borderlessButton).fixedSize().help(L("meeting.duration"))
            }
            if engine.meeting {
                HStack {
                    if let remaining = engine.meetingRemaining {
                        Text(String(format: L("meeting.remaining"), MenuBarStatusFormatter(status: .meeting, remaining: remaining).minutes))
                    } else { Text(L("meeting.indefinite")) }
                    Spacer()
                    Button(L("meeting.end")) { controller.setMeeting(false) }
                }.font(.caption)
            }
            Divider()
            HStack {
                SettingsLink { Label(L("settings"), systemImage: "gearshape") }
                    .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })
                Spacer()
                Menu {
                    Button(L("session.reset")) { confirmReset = true }
                    Button(L("quit")) { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis.circle").accessibilityLabel(L("more")) }
                .menuStyle(.borderlessButton).fixedSize().help(L("more"))
            }.font(.caption)
        }
        .padding(Space.l).frame(width: 330)
        .alert(L("session.reset"), isPresented: $confirmReset) {
            Button(L("cancel"), role: .cancel) {}
            Button(L("session.reset"), role: .destructive) { controller.perform(.reset) }
        } message: { Text(L("session.resetMessage")) }
        .onAppear { controller.tick(); controller.refreshSystemSettings() }
    }
    /// One short line explaining the current state; plain working needs none.
    private var statusNote: String? {
        engine.status == .working ? nil : L("ui.status.note." + engine.status.rawValue)
    }
    /// No transition or animation is attached, so Reduce Motion and default users see the same stable layout.
    private func noticeView(_ notice: TransientNotice) -> some View {
        let text = notice.count.map { String(format: L(notice.textKey), $0) } ?? L(notice.textKey)
        return Label(text, systemImage: notice.count == nil ? "arrow.clockwise" : "checkmark.circle")
            .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
    }
}
