import SwiftUI

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
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.quaternary))
                Text(L(sequence.current.instructionKey)).multilineTextAlignment(.center).frame(minHeight: 42)
                Text(durationText(sequence.displayRemaining(breakRemaining: controller.engine.remaining)))
                    .font(.system(size: 32, weight: .medium, design: .rounded)).monospacedDigit()
                    .accessibilityLabel(L("exercise.remaining"))
                    .accessibilityValue(durationText(sequence.displayRemaining(breakRemaining: controller.engine.remaining)))
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
            }
        }
    }
}
