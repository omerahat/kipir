import SwiftUI

/// Countdown ring: the accent arc is the remaining share of the countdown, anchored at 12 o'clock. It starts full
/// and its free end recedes counterclockwise until nothing is left at zero. `fraction` comes straight from the
/// scheduler (`remainingFraction`); the ring owns no time of its own.
struct CountdownRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 8
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        ZStack {
            // The dark track keeps its approved 12 % tint; light mode needs a little more to stay visible.
            Circle().stroke(.teal.opacity(colorScheme == .dark ? 0.12 : 0.2), lineWidth: lineWidth)
            Circle().trim(from: 0, to: CGFloat(CountdownRingMath.clamped(fraction)))
                .stroke(.teal, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
