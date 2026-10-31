import SwiftUI

/// Rendering time is independent of the countdown. The scheduler remains authoritative.
struct ExerciseAnimationView: View {
    let movement: ExerciseDefinition.Movement
    let elapsed: Double
    let duration: Double
    let frozen: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = ExerciseVisualClock(offset: 0, anchor: 0, running: false)

    private var visualTime: Double {
        clock.time(at: ProcessInfo.processInfo.systemUptime)
    }
    var body: some View {
        Group {
            if reduceMotion {
                HStack(spacing: 4) {
                    drawing(phase: 0).overlay(alignment: .bottom) { Text(L("pose.start")).font(.caption2) }
                    drawing(phase: movement == .shoulders || movement == .walk ? .pi / 2 : .pi).overlay(alignment: .bottom) { Text(L("pose.end")).font(.caption2) }
                }
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: frozen)) { _ in
                    drawing(phase: visualTime * .pi / 2)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("exercise." + movement.rawValue + ".instruction"))
        .onAppear {
            clock = ExerciseVisualClock(offset: elapsed, anchor: ProcessInfo.processInfo.systemUptime, running: !frozen)
        }
        .onChange(of: frozen) { _, value in
            clock.setRunning(!value, at: ProcessInfo.processInfo.systemUptime)
        }
    }
    private func drawing(phase: Double) -> some View {
        Canvas { context, size in
            let scale = min(size.width / 240, size.height / 180)
            context.translateBy(x: (size.width - 240 * scale) / 2, y: (size.height - 180 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            ExerciseArtwork.draw(&context, movement: movement, phase: phase,
                                 alternateHand: elapsed >= duration / 2)
        }.accessibilityHidden(true)
    }
}

enum ExerciseArtwork {
    private static let skin = Color(red: 0.79, green: 0.57, blue: 0.46)
    private static let skinLight = Color(red: 0.87, green: 0.67, blue: 0.55)
    private static let shirt = Color(red: 0.16, green: 0.56, blue: 0.54)
    private static let pants = Color(red: 0.31, green: 0.43, blue: 0.45)
    private static let shoe = Color(red: 0.25, green: 0.36, blue: 0.38)
    private static let accent = Color(red: 0.93, green: 0.65, blue: 0.40)

    private struct Point { var x: Double; var y: Double }
    private struct Limb { var shoulder: Point; var elbow: Point; var hand: Point }
    private static func path(_ points: [Point]) -> Path {
        var p = Path(); p.move(to: CGPoint(x: points[0].x, y: points[0].y))
        for v in points.dropFirst() { p.addLine(to: CGPoint(x: v.x, y: v.y)) }
        return p
    }
    private static func capsule(_ c: inout GraphicsContext, _ a: Point, _ b: Point, width: Double, color: Color) {
        c.stroke(path([a, b]), with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
    private static func oval(_ c: inout GraphicsContext, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color) {
        c.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
    }
    private static func arm(_ c: inout GraphicsContext, _ arm: Limb, back: Bool = false) {
        capsule(&c, arm.shoulder, arm.elbow, width: 15, color: shirt.opacity(back ? 0.75 : 1))
        capsule(&c, arm.elbow, arm.hand, width: 10, color: back ? skin : skinLight)
        oval(&c, arm.hand.x - 5, arm.hand.y - 5, 10, 12, back ? skin : skinLight)
    }
    static func draw(_ c: inout GraphicsContext, movement: ExerciseDefinition.Movement, phase: Double, alternateHand: Bool) {
        let wave = (1 - cos(phase)) / 2
        if movement == .wrists { wrists(&c, wave: wave, mirrored: alternateHand); return }
        if movement == .calves { side(&c, wave: wave); return }
        if movement == .walk { walk(&c, phase: phase); return }
        let stride = movement == .walk ? sin(phase) : 0
        let shoulderRoll = movement == .shoulders ? sin(phase) * 5 : 0
        let shoulderDepth = movement == .shoulders ? cos(phase) * 3 : 0
        let open = movement == .chest ? wave : 0
        let hip = 103.0
        let leftFoot = Point(x: 105 + stride * 17, y: 164 - max(0, stride) * 8)
        let rightFoot = Point(x: 135 - stride * 17, y: 164 - max(0, -stride) * 8)
        oval(&c, 84, 168, 72, 5, .black.opacity(0.09))
        func leg(_ start: Point, _ knee: Point, _ foot: Point, darker: Bool) {
            let color = darker ? pants.opacity(0.75) : pants
            capsule(&c, start, knee, width: 17, color: color)
            capsule(&c, knee, foot, width: 14, color: color)
            capsule(&c, foot, Point(x: foot.x + 9, y: foot.y + 1), width: 9, color: shoe)
        }
        leg(Point(x: 111, y: hip), Point(x: 108 + stride * 8, y: 134 - max(0, stride) * 3), leftFoot, darker: true)
        leg(Point(x: 129, y: hip), Point(x: 132 - stride * 8, y: 134 - max(0, -stride) * 3), rightFoot, darker: false)
        let l = Limb(shoulder: Point(x: 99 - shoulderDepth, y: 55 + shoulderRoll), elbow: Point(x: 95 - open * 16 + stride * 5, y: 81 - open * 10 + shoulderRoll), hand: Point(x: 101 - open * 42 + stride * 8, y: 105 - open * 37 + shoulderRoll))
        let r = Limb(shoulder: Point(x: 141 + shoulderDepth, y: 55 + shoulderRoll), elbow: Point(x: 145 + open * 16 - stride * 5, y: 81 - open * 10 + shoulderRoll), hand: Point(x: 139 + open * 42 - stride * 8, y: 105 - open * 37 + shoulderRoll))
        arm(&c, l, back: true); arm(&c, r)
        var torso = Path(); torso.move(to: CGPoint(x: 103, y: 49)); torso.addQuadCurve(to: CGPoint(x: 137, y: 49), control: CGPoint(x: 120, y: 43)); torso.addQuadCurve(to: CGPoint(x: 139, y: 105), control: CGPoint(x: 144, y: 74)); torso.addQuadCurve(to: CGPoint(x: 101, y: 105), control: CGPoint(x: 120, y: 111)); torso.addQuadCurve(to: CGPoint(x: 103, y: 49), control: CGPoint(x: 96, y: 74)); torso.closeSubpath(); c.fill(torso, with: .color(shirt))
        capsule(&c, Point(x: 120, y: 43), Point(x: 120, y: 52), width: 10, color: skin)
        oval(&c, 105, 10, 30, 34, skinLight)
        var hair = Path(); hair.move(to: CGPoint(x: 105, y: 27)); hair.addCurve(to: CGPoint(x: 135, y: 24), control1: CGPoint(x: 98, y: 4), control2: CGPoint(x: 137, y: 2)); hair.addQuadCurve(to: CGPoint(x: 105, y: 27), control: CGPoint(x: 121, y: 11)); c.fill(hair, with: .color(pants))
        oval(&c, 112, 26, 2, 2, pants); oval(&c, 126, 26, 2, 2, pants)
        if movement == .shoulders {
            oval(&c, 95 - shoulderDepth, 49 + shoulderRoll, 8, 8, accent.opacity(0.9))
            oval(&c, 137 + shoulderDepth, 49 + shoulderRoll, 8, 8, accent.opacity(0.9))
        }
    }
    private static func side(_ c: inout GraphicsContext, wave: Double) {
        let lift = 10 * wave
        oval(&c, 83, 168, 85, 5, .black.opacity(0.09))
        // Toe stays on the ground as the ankle and heel rise.
        capsule(&c, Point(x: 116, y: 105-lift), Point(x: 112, y: 135-lift), width: 19, color: pants)
        capsule(&c, Point(x: 112, y: 135-lift), Point(x: 112, y: 161-lift), width: 15, color: pants)
        capsule(&c, Point(x: 110, y: 164-lift), Point(x: 144, y: 166), width: 9, color: shoe)
        capsule(&c, Point(x: 118, y: 52-lift), Point(x: 119, y: 101-lift), width: 35, color: shirt)
        capsule(&c, Point(x: 117, y: 55-lift), Point(x: 127, y: 78-lift), width: 13, color: shirt)
        capsule(&c, Point(x: 127, y: 78-lift), Point(x: 150, y: 75), width: 9, color: skinLight)
        capsule(&c, Point(x: 120, y: 43-lift), Point(x: 120, y: 51-lift), width: 9, color: skin)
        oval(&c, 106, 11-lift, 28, 33, skinLight)
        oval(&c, 105, 9-lift, 26, 13, pants)
        oval(&c, 127, 27-lift, 2, 2, pants)
        capsule(&c, Point(x: 155, y: 77), Point(x: 155, y: 163), width: 3, color: .secondary.opacity(0.45))
        capsule(&c, Point(x: 143, y: 76), Point(x: 174, y: 76), width: 4, color: .secondary.opacity(0.45))
    }
    private static func walk(_ c: inout GraphicsContext, phase: Double) {
        let step = sin(phase)
        let backLift = max(0, step)
        let frontLift = max(0, -step)
        oval(&c, 80, 168, 88, 5, .black.opacity(0.09))
        func leg(_ lift: Double, color: Color) {
            let ankle = Point(x: 111 + 12 * lift, y: 162 - 13 * lift)
            let knee = Point(x: 113 + 12 * lift, y: 134 - 5 * lift)
            capsule(&c, Point(x: 117, y: 102), knee, width: 17, color: color)
            capsule(&c, knee, ankle, width: 13, color: color)
            capsule(&c, ankle, Point(x: ankle.x + 16, y: ankle.y + 2), width: 9, color: shoe)
        }
        leg(backLift, color: pants.opacity(0.65))
        let backArm = Limb(shoulder: Point(x: 119, y: 55), elbow: Point(x: 111 - 5 * step, y: 77), hand: Point(x: 109 - 11 * step, y: 95))
        arm(&c, backArm, back: true)
        capsule(&c, Point(x: 118, y: 52), Point(x: 118, y: 101), width: 35, color: shirt)
        leg(frontLift, color: pants)
        let frontArm = Limb(shoulder: Point(x: 120, y: 55), elbow: Point(x: 127 + 5 * step, y: 77), hand: Point(x: 129 + 11 * step, y: 95))
        arm(&c, frontArm)
        capsule(&c, Point(x: 120, y: 43), Point(x: 120, y: 51), width: 9, color: skin)
        oval(&c, 106, 11, 28, 33, skinLight)
        oval(&c, 105, 9, 26, 13, pants)
        oval(&c, 127, 27, 2, 2, pants)
    }
    private static func wrists(_ c: inout GraphicsContext, wave: Double, mirrored: Bool) {
        if mirrored { c.translateBy(x: 240, y: 0); c.scaleBy(x: -1, y: 1) }
        capsule(&c, Point(x: 33, y: 130), Point(x: 100, y: 96), width: 30, color: shirt)
        capsule(&c, Point(x: 89, y: 101), Point(x: 136, y: 79), width: 24, color: skinLight)
        capsule(&c, Point(x: 134, y: 80), Point(x: 140 - wave * 5, y: 45 - wave * 8), width: 14, color: skinLight)
        for i in 0..<4 {
            capsule(&c, Point(x: 133 + Double(i)*5, y: 57), Point(x: 133 + Double(i)*5 - wave*4, y: 37 - wave*7), width: 5, color: skinLight)
        }
        capsule(&c, Point(x: 210, y: 136), Point(x: 170, y: 105), width: 30, color: shirt.opacity(0.8))
        capsule(&c, Point(x: 170, y: 105), Point(x: 148, y: 67), width: 20, color: skin)
        capsule(&c, Point(x: 149, y: 70), Point(x: 132, y: 62 - wave * 5), width: 10, color: skin)
        oval(&c, 125, 69, 12, 12, accent.opacity(0.7))
    }
}
