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
            if engine.checkpoint.phase == .onBreak {
                BreakExerciseView(controller: controller)
            } else {
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
                    }
                }.controlSize(.large)
                if engine.status == .due {
                    HStack {
                        Button(L("snooze")) { controller.perform(.snooze) }
                        Button(L("skip")) { controller.perform(.skip) }
                    }
                }
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
            }
            HStack {
                Toggle(isOn: Binding(get: { engine.meeting }, set: { controller.setMeeting($0) })) {
                    Label(L("meeting"), systemImage: "person.2")
                }.toggleStyle(.switch)
                Menu {
                    ForEach([15, 30, 60], id: \.self) { minutes in
                        Button(String(format: L("menubar.minutes"), minutes)) { controller.setMeeting(true, minutes: minutes) }
                    }
                    Button(L("meeting.indefinite")) { controller.setMeeting(true) }
                } label: { Image(systemName: "clock").accessibilityLabel(L("meeting.duration")) }
                .menuStyle(.borderlessButton).fixedSize()
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

struct BreakExerciseView: View {
    @ObservedObject var controller: AppController
    var body: some View {
        if let sequence = controller.engine.exercises {
            VStack(spacing: 10) {
                HStack {
                    Text(L(sequence.current.nameKey)).font(.headline)
                    Spacer()
                    Text("\(sequence.index + 1) / \(sequence.exercises.count)").foregroundStyle(.secondary)
                }
                ExerciseAnimationView(movement: sequence.current.id, elapsed: sequence.elapsed, duration: sequence.current.duration, frozen: controller.engine.status != .onBreak)
                    .id(sequence.current.id)
                    .frame(height: 180).padding(8)
                    .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                Text(L(sequence.current.instructionKey)).multilineTextAlignment(.center).frame(minHeight: 42)
                Text(durationText((sequence.index == sequence.exercises.count - 1 ? controller.engine.remaining : min(sequence.remaining, controller.engine.remaining))))
                    .font(.system(size: 32, weight: .medium, design: .rounded)).monospacedDigit()
                    .accessibilityLabel(L("exercise.remaining"))
                    .accessibilityValue(durationText((sequence.index == sequence.exercises.count - 1 ? controller.engine.remaining : min(sequence.remaining, controller.engine.remaining))))
                ProgressView(value: controller.engine.progress).tint(.teal).accessibilityLabel(L("exercise.progress"))
                HStack {
                    Button(L("exercise.previous")) { controller.navigateExercise(-1) }.disabled(sequence.index == 0).keyboardShortcut(.leftArrow, modifiers: [])
                    Button(L(controller.engine.paused ? "resume" : "pause")) { controller.perform(.togglePause) }.keyboardShortcut(.space, modifiers: [])
                    Button(L("exercise.next")) { controller.navigateExercise(1) }.disabled(sequence.index == sequence.exercises.count - 1).keyboardShortcut(.rightArrow, modifiers: [])
                }
                HStack {
                    Button(L("exercise.skip")) {
                        if sequence.index == sequence.exercises.count - 1 { controller.perform(.skip) }
                        else { controller.navigateExercise(1) }
                    }
                    Spacer()
                    Button(L("break.end")) { controller.perform(.skip) }
                }
                Text(L("exercise.safety")).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.preferredColorScheme(controller.colorScheme)
        }
    }
}
