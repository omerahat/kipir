import SwiftUI

/// Two illustrated key poses per movement (`exercise-<movement>-start|end` in the asset catalog),
/// held and briefly crossfaded on a loop. Rendering time is independent of the countdown: the
/// visual clock only follows scheduler-accepted elapsed time and never advances scheduling.
struct ExerciseAnimationView: View {
    let movement: ExerciseDefinition.Movement
    let elapsed: Double
    let duration: Double
    let frozen: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = ExerciseVisualClock(offset: 0, anchor: 0, running: false)

    private var uptime: Double { ProcessInfo.processInfo.systemUptime }
    private var period: Double { ExerciseDefinition.loopPeriod(duration: duration, base: movement.basePeriod) }

    var body: some View {
        Group {
            if reduceMotion {
                // Reduce Motion: both poses side by side, still, with labels.
                HStack(spacing: 8) {
                    still("start", label: "pose.start")
                    still("end", label: "pose.end")
                }
            } else {
                // At most 30 fps, and only while running (frozen == paused/suspended/not on break).
                TimelineView(.animation(minimumInterval: 1 / 30, paused: frozen)) { _ in
                    let time = clock.time(at: uptime)
                    let blend = exercisePoseBlend(phase: time / period)
                    ZStack {
                        pose("start").opacity(1 - blend)
                        pose("end").opacity(blend)
                    }
                    // The wrist stretch switches hands halfway through the movement.
                    .scaleEffect(x: movement == .wrists && time >= duration / 2 ? -1 : 1, y: 1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("exercise." + movement.rawValue) + ". " + L("exercise." + movement.rawValue + ".instruction"))
        .onAppear {
            clock = ExerciseVisualClock(offset: elapsed, anchor: uptime, running: !frozen)
        }
        .onChange(of: frozen) { _, value in
            clock.setRunning(!value, at: uptime)
        }
        .onChange(of: elapsed) { _, accepted in
            // Re-anchor only after a real divergence (an awake gap the scheduler did not credit).
            if exerciseVisualNeedsResync(visual: clock.time(at: uptime), accepted: accepted) {
                clock = ExerciseVisualClock(offset: accepted, anchor: uptime, running: !frozen)
            }
        }
    }

    private func pose(_ name: String) -> some View {
        Image("exercise-\(movement.rawValue)-\(name)")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
    }
    private func still(_ name: String, label: String) -> some View {
        VStack(spacing: 2) {
            pose(name)
            Text(L(label)).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
