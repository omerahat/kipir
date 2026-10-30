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
            Toggle(isOn: Binding(get: { engine.meeting }, set: { _ in controller.perform(.toggleMeeting) })) {
                Label(L("meeting"), systemImage: "person.2")
            }.toggleStyle(.switch)
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

struct ExerciseFigureView: View {
    let movement: ExerciseDefinition.Movement
    let frozen: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            HStack {
                figure(phase: 0).overlay(alignment: .bottom) { Text(L("pose.start")).font(.caption) }
                figure(phase: movement == .shoulders || movement == .walk ? .pi / 2 : .pi).overlay(alignment: .bottom) { Text(L("pose.end")).font(.caption) }
            }.accessibilityLabel(L("exercise." + movement.rawValue + ".instruction"))
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: frozen)) { context in
                figure(phase: frozen ? 0 : context.date.timeIntervalSinceReferenceDate * .pi / 2)
            }.accessibilityLabel(L("exercise." + movement.rawValue + ".instruction"))
        }
    }
    private func figure(phase: Double) -> some View {
        Canvas { context, size in
            let scale = min(size.width / 240, size.height / 290)
            let origin = CGPoint(x: (size.width - 240 * scale) / 2, y: (size.height - 290 * scale) / 2)
            func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: origin.x + x * scale, y: origin.y + y * scale) }
            let wave = (1 - cos(phase)) / 2
            let lift = movement == .calves ? 12 * wave : 0
            let shoulder = movement == .shoulders ? 7 * sin(phase) : 0
            let sway = movement == .walk ? sin(phase) * 12 : 0
            let leftStep = movement == .walk ? max(0, sin(phase)) * 16 : 0
            let rightStep = movement == .walk ? max(0, -sin(phase)) * 16 : 0
            func line(_ coordinates: [(Double, Double)], color: Color = .primary, width: Double = 9) {
                var path = Path()
                for (i, p) in coordinates.enumerated() {
                    if i == 0 { path.move(to: point(p.0, p.1)) } else { path.addLine(to: point(p.0, p.1)) }
                }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width * scale, lineCap: .round, lineJoin: .round))
            }
            // Front-facing simplified skeleton; elbow and wrist positions are explicit for each movement.
            context.fill(Path(ellipseIn: CGRect(x: point(104, 25 - lift).x, y: point(104, 25 - lift).y, width: 32 * scale, height: 36 * scale)), with: .color(.primary))
            line([(120, 70 - lift), (120, 160 - lift)])
            line([(91, 86 - lift + shoulder), (120, 80 - lift), (149, 86 - lift + shoulder)], color: .teal)
            switch movement {
            case .shoulders:
                for side in [-1.0, 1.0] {
                    let x = 120 + side * (30 + 4 * cos(phase))
                    line([(x, 86 + shoulder), (x + side * 8, 120 + shoulder), (x + side * 3, 151 + shoulder)], color: .teal)
                }
            case .chest:
                for side in [-1.0, 1.0] {
                    line([(120 + side * 29, 86), (120 + side * (38 + 23 * wave), 116 - 22 * wave), (120 + side * (18 + 73 * wave), 140 - 47 * wave)], color: .teal)
                }
            case .wrists:
                line([(91, 86), (74, 118), (124, 118)], color: .teal)
                line([(149, 86), (159, 118), (126, 118)], color: .teal)
                line([(124, 118), (124 + 8 * wave, 96)], color: .orange, width: 6)
                line([(126, 118), (133, 104)], color: .orange, width: 5)
            case .calves, .walk:
                line([(91, 86 - lift), (80 + sway, 123 - lift), (88 + sway, 152 - lift)], color: .teal)
                line([(149, 86 - lift), (160 - sway, 123 - lift), (152 - sway, 152 - lift)], color: .teal)
            }
            line([(120, 160 - lift), (100 + sway, 204 - lift - leftStep), (98 + sway, 249 - lift - leftStep)])
            line([(120, 160 - lift), (140 - sway, 204 - lift - rightStep), (142 - sway, 249 - lift - rightStep)])
            line([(98 + sway, 249 - lift - leftStep), (82 + sway, 252 - leftStep)])
            line([(142 - sway, 249 - lift - rightStep), (158 - sway, 252 - rightStep)])
            line([(62, 260), (178, 260)], color: .secondary.opacity(0.3), width: 2)
        }.accessibilityHidden(true)
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
                ExerciseFigureView(movement: sequence.current.id, frozen: controller.engine.status != .onBreak)
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
