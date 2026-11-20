import SwiftUI

/// Countdown ring: the accent arc is the remaining share of the countdown, anchored at 12 o'clock. It starts full
/// and its free end recedes counterclockwise until nothing is left at zero. `fraction` comes straight from the
/// scheduler (`remainingFraction`); the ring owns no time of its own.
struct CountdownRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 8
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// What is drawn. The scheduler only advances on the 1 s heartbeat, so drawing `fraction` directly makes the
    /// arc step once a second. A forward tick is instead interpolated linearly over one heartbeat: rendering only,
    /// no timer and no time of its own. Any other change (snooze refill, reset, new break) and Reduce Motion jump.
    @State private var shown: Double?
    private let heartbeat: Double = 1
    var body: some View {
        ZStack {
            // The dark track keeps its approved 12 % tint; light mode needs a little more to stay visible.
            Circle().stroke(.teal.opacity(colorScheme == .dark ? 0.12 : 0.2), lineWidth: lineWidth)
            Circle().trim(from: 0, to: CGFloat(CountdownRingMath.clamped(shown ?? fraction)))
                .stroke(.teal, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .onChange(of: fraction) { old, new in
            let ticking = new < old && !reduceMotion && old - new < 0.5
            if ticking { withAnimation(.linear(duration: heartbeat)) { shown = new } } else { shown = new }
        }
    }
}
