import SwiftUI

/// Rendering time is independent of the countdown. The scheduler remains authoritative.
struct ExerciseAnimationView: View {
    let movement: ExerciseDefinition.Movement
    let elapsed: Double
    let duration: Double
    let frozen: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = ExerciseVisualClock(offset: 0, anchor: 0, running: false)

    private var uptime: Double { ProcessInfo.processInfo.systemUptime }
    var body: some View {
        Group {
            if reduceMotion {
                // Reduce Motion: two labeled still key poses, no TimelineView.
                let keys = ExerciseArtwork.stillKeys(movement)
                HStack(spacing: 4) {
                    still(key: keys.start, label: "pose.start")
                    still(key: keys.end, label: "pose.end")
                }
            } else {
                // At most 30 fps, and only redrawn while running (frozen == paused/suspended/not on break).
                TimelineView(.animation(minimumInterval: 1 / 30, paused: frozen)) { _ in
                    let time = clock.time(at: uptime)
                    drawing { context in
                        ExerciseArtwork.draw(&context, movement: movement,
                                             loop: time / ExerciseDefinition.loopPeriod(duration: duration, base: movement.basePeriod),
                                             alternateHand: time >= duration / 2)
                    }
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
    private func still(key: Int, label: String) -> some View {
        VStack(spacing: 2) {
            drawing { context in ExerciseArtwork.drawKey(&context, movement: movement, key: key, alternateHand: false) }
            Text(L(label)).font(.caption2).foregroundStyle(.secondary)
        }
    }
    private func drawing(_ body: @escaping (inout GraphicsContext) -> Void) -> some View {
        Canvas { context, size in
            let scale = min(size.width / 240, size.height / 180)
            context.translateBy(x: (size.width - 240 * scale) / 2, y: (size.height - 180 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            body(&context)
        }.accessibilityHidden(true)
    }
}

/// Flat vector figure. Every movement is 2-4 explicit key poses (joint data) blended on a loop with
/// held cosine easing; one shared skeleton, palette and drawing routine keeps the style consistent.
enum ExerciseArtwork {
    typealias Movement = ExerciseDefinition.Movement
    private static let skin = Color(red: 0.80, green: 0.58, blue: 0.46), skinFar = Color(red: 0.66, green: 0.46, blue: 0.37)
    private static let shirt = Color(red: 0.16, green: 0.56, blue: 0.54), shirtFar = Color(red: 0.11, green: 0.42, blue: 0.41)
    private static let pants = Color(red: 0.38, green: 0.46, blue: 0.58), pantsFar = Color(red: 0.28, green: 0.35, blue: 0.46)
    private static let shoe = Color(red: 0.93, green: 0.65, blue: 0.40), shoeFar = Color(red: 0.78, green: 0.52, blue: 0.30)
    private static let hair = Color(red: 0.22, green: 0.20, blue: 0.24)
    private static let prop = Color(red: 0.55, green: 0.58, blue: 0.62)
    private static let accent = Color(red: 0.93, green: 0.65, blue: 0.40)

    // MARK: Skeleton and key-pose interpolation

    struct P { var x: Double; var y: Double }
    private static func p(_ x: Double, _ y: Double) -> P { P(x: x, y: y) }
    private enum J: Int, CaseIterable { case head, shL, shR, elL, elR, haL, haR, hiL, hiR, knL, knR, ftL, ftR, toL, toR, spine }
    private struct Pose {
        var pts: [P]; var tilt = 0.0
        subscript(_ j: J) -> P { get { pts[j.rawValue] } set { pts[j.rawValue] = newValue } }
        /// Derived pose: edits replace joints; feet keep their toe offset unless the toe is edited too.
        func with(_ edits: [J: P], tilt: Double = 0) -> Pose {
            var r = self; r.tilt = tilt
            for (foot, toe) in [(J.ftL, J.toL), (J.ftR, J.toR)] where edits[foot] != nil && edits[toe] == nil {
                r[toe] = P(x: edits[foot]!.x + (self[toe].x - self[foot].x), y: edits[foot]!.y + (self[toe].y - self[foot].y))
            }
            for (j, v) in edits { r[j] = v }
            return r
        }
        var flat: [Double] { pts.flatMap { [$0.x, $0.y] } + [tilt] }
        init(flat v: [Double]) { pts = (0..<J.allCases.count).map { P(x: v[$0 * 2], y: v[$0 * 2 + 1]) }; tilt = v[J.allCases.count * 2] }
        init(_ list: [P]) { pts = list }
    }
    /// Shared helper: loops through `keys` (`t` in loop fractions), holding each key briefly and
    /// easing between neighbours with a cosine curve.
    static func blend(_ keys: [[Double]], loop t: Double) -> [Double] {
        guard keys.count > 1, t.isFinite else { return keys.first ?? [] }
        let scaled = (t - floor(t)) * Double(keys.count)
        let seg = min(keys.count - 1, Int(scaled)), hold = 0.12
        let s = min(1, max(0, (scaled - Double(seg) - hold) / (1 - 2 * hold)))
        let e = (1 - cos(.pi * s)) / 2
        let a = keys[seg], b = keys[(seg + 1) % keys.count]
        return zip(a, b).map { $0 + ($1 - $0) * e }
    }

    private static func make(_ base: [J: (Double, Double)]) -> Pose {
        Pose(J.allCases.map { j in base[j].map { p($0.0, $0.1) } ?? p(0, 0) })
    }
    private static let front = make([.head: (120, 29), .shL: (101, 58), .shR: (139, 58), .elL: (95, 85), .elR: (145, 85), .haL: (94, 110), .haR: (146, 110),
        .hiL: (110, 108), .hiR: (130, 108), .knL: (108, 135), .knR: (132, 135), .ftL: (107, 162), .ftR: (133, 162), .toL: (99, 164), .toR: (141, 164), .spine: (120, 84)])
    private static let side = make([.head: (121, 29), .shL: (119, 58), .shR: (116, 58), .elL: (118, 84), .elR: (115, 84), .haL: (119, 108), .haR: (115, 108),
        .hiL: (116, 108), .hiR: (114, 108), .knL: (118, 135), .knR: (114, 135), .ftL: (116, 162), .ftR: (113, 162), .toL: (133, 164), .toR: (130, 164), .spine: (117, 83)])
    private static let seatedSide = side.with([.head: p(104, 29), .shL: p(101, 58), .shR: p(99, 58), .elL: p(106, 88), .elR: p(104, 88), .haL: p(128, 110), .haR: p(124, 110),
        .hiL: p(96, 116), .hiR: p(94, 116), .knL: p(134, 118), .knR: p(132, 118), .ftL: p(136, 160), .ftR: p(134, 160), .spine: p(97, 87)])
    private static let seatedFront = front.with([.hiL: p(110, 116), .hiR: p(130, 116), .knL: p(104, 124), .knR: p(136, 124), .ftL: p(104, 162), .ftR: p(136, 162),
        .haL: p(110, 120), .haR: p(130, 120), .elL: p(98, 88), .elR: p(142, 88)])

    private enum ViewKind { case front, side }
    private struct Scene { var view: ViewKind; var keys: [Pose]; var decor: (inout GraphicsContext, Pose) -> Void = { _, _ in } }

    private static func scene(_ m: Movement) -> Scene {
        switch m {
        case .shoulders:
            func s(_ dx: Double, _ dy: Double) -> Pose {
                front.with([.shL: p(101 + dx, 58 + dy), .shR: p(139 - dx, 58 + dy), .elL: p(95 + dx, 85 + dy), .elR: p(145 - dx, 85 + dy), .haL: p(94 + dx, 110 + dy), .haR: p(146 - dx, 110 + dy)])
            }
            return Scene(view: .front, keys: [s(3, -7), s(-5, 0), s(-1, 7)], decor: { c, _ in
                arcArrow(&c, center: p(80, 54), radius: 10, from: 200, to: 470); arcArrow(&c, center: p(160, 54), radius: 10, from: 200, to: 470, mirror: true)
            })
        case .shrug:
            let down = front, up = front.with([.head: p(120, 35), .shL: p(106, 46), .shR: p(134, 46), .elL: p(92, 74), .elR: p(148, 74), .haL: p(90, 98), .haR: p(150, 98)])
            return Scene(view: .front, keys: [down, up])
        case .neckTilt:
            func t(_ s: Double) -> Pose { front.with([.head: p(120 + 13 * s, 32 + 1)], tilt: 0.38 * s) }
            return Scene(view: .front, keys: [t(-1), t(1)])
        case .chest:
            let closed = front.with([.elL: p(103, 80), .elR: p(137, 80), .haL: p(118, 74), .haR: p(122, 74)])
            let open = front.with([.shL: p(98, 58), .shR: p(142, 58), .head: p(120, 27), .elL: p(76, 66), .elR: p(164, 66), .haL: p(52, 56), .haR: p(188, 56)])
            return Scene(view: .front, keys: [closed, open])
        case .upperBack:
            let upright = seatedSide
            let round = seatedSide.with([.head: p(126, 50), .shL: p(110, 66), .shR: p(108, 66), .elL: p(136, 68), .elR: p(134, 67), .haL: p(162, 68), .haR: p(160, 67), .spine: p(84, 87)])
            return Scene(view: .side, keys: [upright, round], decor: { c, _ in chair(&c) })
        case .twist:
            let left = seatedFront.with([.head: p(115, 31), .shL: p(108, 60), .shR: p(134, 55), .elL: p(98, 82), .haL: p(88, 96), .elR: p(128, 90), .haR: p(106, 122), .spine: p(121, 84)])
            let right = seatedFront.with([.head: p(125, 31), .shL: p(106, 55), .shR: p(132, 60), .elR: p(142, 82), .haR: p(152, 96), .elL: p(112, 90), .haL: p(134, 122), .spine: p(119, 84)])
            return Scene(view: .front, keys: [left, right], decor: { c, _ in backrest(&c) })
        case .calves:
            func s(_ lift: Double) -> Pose {
                side.with([.head: p(121, 29 - lift), .shL: p(119, 58 - lift), .shR: p(116, 58 - lift), .elL: p(136, 76 - lift * 0.4), .elR: p(133, 75 - lift * 0.4), .haL: p(153, 83), .haR: p(150, 83),
                           .hiL: p(116, 108 - lift), .hiR: p(114, 108 - lift), .knL: p(118, 135 - lift), .knR: p(114, 135 - lift), .ftL: p(116, 162 - lift), .ftR: p(113, 162 - lift),
                           .toL: p(133, 164), .toR: p(130, 164), .spine: p(117, 83 - lift)])
            }
            return Scene(view: .side, keys: [s(0), s(12)], decor: { c, _ in desk(&c) })
        case .march:
            func s(_ near: Bool) -> Pose {
                let up: [J: P] = [near ? .knL : .knR: p(136, 114), near ? .ftL : .ftR: p(132, 141)]
                let arms: [J: P] = near ? [.elL: p(104, 82), .haL: p(100, 100), .elR: p(130, 82), .haR: p(142, 70)]
                                        : [.elR: p(101, 82), .haR: p(97, 100), .elL: p(133, 82), .haL: p(145, 70)]
                return side.with(up.merging(arms) { a, _ in a })
            }
            return Scene(view: .side, keys: [s(true), s(false)])
        case .walk:
            let contactNear = side.with([.knL: p(128, 134), .ftL: p(136, 161), .toL: p(150, 158), .knR: p(104, 136), .ftR: p(94, 155), .elL: p(112, 83), .haL: p(104, 104), .elR: p(122, 83), .haR: p(132, 102)])
            let passFar = side.with([.knR: p(124, 128), .ftR: p(110, 150), .toR: p(124, 152)])
            let contactFar = side.with([.knR: p(128, 134), .ftR: p(136, 161), .toR: p(150, 158), .knL: p(104, 136), .ftL: p(94, 155), .elR: p(112, 83), .haR: p(104, 104), .elL: p(122, 83), .haL: p(132, 102)])
            let passNear = side.with([.knL: p(124, 128), .ftL: p(110, 150), .toL: p(124, 152)])
            return Scene(view: .side, keys: [contactNear, passFar, contactFar, passNear], decor: { c, _ in walkAway(&c) })
        case .wrists, .fingers: return Scene(view: .front, keys: [])
        }
    }

    /// Key indices shown for Reduce Motion (start / end).
    static func stillKeys(_ m: Movement) -> (start: Int, end: Int) {
        switch m {
        case .walk, .shoulders: return (0, 2)
        default: return (0, 1)
        }
    }
    static func keyCount(_ m: Movement) -> Int {
        switch m { case .wrists, .fingers: return 2; default: return scene(m).keys.count }
    }

    // MARK: Entry points

    static func draw(_ c: inout GraphicsContext, movement: Movement, loop: Double, alternateHand: Bool) {
        render(&c, movement, alternateHand) { keys in blend(keys, loop: loop) }
    }
    static func drawKey(_ c: inout GraphicsContext, movement: Movement, key: Int, alternateHand: Bool) {
        render(&c, movement, alternateHand) { keys in keys[min(max(0, key), keys.count - 1)] }
    }
    private static func render(_ c: inout GraphicsContext, _ m: Movement, _ alternate: Bool, _ pick: ([[Double]]) -> [Double]) {
        switch m {
        case .wrists:
            wrists(&c, angle: pick([[-0.3], [-1.4]])[0], mirrored: alternate)
        case .fingers:
            fingers(&c, pick([[0.24, 44, -2.2, 32, 0], [0.0, 20, -0.25, 28, 1]]))
        default:
            let sc = scene(m)
            let pose = Pose(flat: pick(sc.keys.map(\.flat)))
            ground(&c)
            sc.decor(&c, pose)
            figure(&c, pose, view: sc.view)
        }
    }

    // MARK: Drawing primitives

    private static func line(_ c: inout GraphicsContext, _ a: P, _ b: P, _ w: Double, _ color: Color) {
        var path = Path(); path.move(to: CGPoint(x: a.x, y: a.y)); path.addLine(to: CGPoint(x: b.x, y: b.y))
        c.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }
    private static func dot(_ c: inout GraphicsContext, _ a: P, _ r: Double, _ color: Color) {
        c.fill(Path(ellipseIn: CGRect(x: a.x - r, y: a.y - r, width: 2 * r, height: 2 * r)), with: .color(color))
    }
    private static func ground(_ c: inout GraphicsContext) { line(&c, p(40, 170), p(200, 170), 2, prop) }
    private static func arcArrow(_ c: inout GraphicsContext, center: P, radius r: Double, from a: Double, to b: Double, mirror: Bool = false) {
        var path = Path()
        let pts = stride(from: a, through: b, by: 15).map { p(center.x + (mirror ? -1 : 1) * r * cos($0 * .pi / 180), center.y + r * sin($0 * .pi / 180)) }
        guard let first = pts.first, let last = pts.last, pts.count > 1 else { return }
        path.move(to: CGPoint(x: first.x, y: first.y)); for v in pts.dropFirst() { path.addLine(to: CGPoint(x: v.x, y: v.y)) }
        c.stroke(path, with: .color(accent), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        let prev = pts[pts.count - 2], ang = atan2(last.y - prev.y, last.x - prev.x)
        for d in [2.6, -2.6] { line(&c, last, p(last.x - 7 * cos(ang + d * 0.25), last.y - 7 * sin(ang + d * 0.25)), 3, accent) }
    }
    private static func chair(_ c: inout GraphicsContext) {
        line(&c, p(80, 127), p(116, 127), 5, prop); line(&c, p(80, 127), p(80, 74), 5, prop)
        line(&c, p(84, 127), p(84, 168), 4, prop); line(&c, p(112, 127), p(112, 168), 4, prop)
    }
    private static func backrest(_ c: inout GraphicsContext) {
        line(&c, p(92, 66), p(148, 66), 5, prop); line(&c, p(92, 66), p(92, 100), 5, prop); line(&c, p(148, 66), p(148, 100), 5, prop)
        line(&c, p(96, 127), p(144, 127), 5, prop)
    }
    private static func desk(_ c: inout GraphicsContext) {
        line(&c, p(146, 90), p(214, 90), 6, prop); line(&c, p(208, 90), p(208, 168), 5, prop)
    }
    private static func walkAway(_ c: inout GraphicsContext) {
        line(&c, p(8, 92), p(54, 92), 6, prop); line(&c, p(12, 92), p(12, 168), 5, prop)
        line(&c, p(172, 40), p(206, 40), 4, accent); line(&c, p(206, 40), p(198, 33), 4, accent); line(&c, p(206, 40), p(198, 47), 4, accent)
    }

    // MARK: Figure

    private static func figure(_ c: inout GraphicsContext, _ pose: Pose, view: ViewKind) {
        let isSide = view == .side
        func leg(_ hip: J, _ knee: J, _ ankle: J, _ toe: J, far: Bool) {
            line(&c, pose[hip], pose[knee], 16, far ? pantsFar : pants)
            line(&c, pose[knee], pose[ankle], 13, far ? pantsFar : pants)
            line(&c, pose[ankle], pose[toe], 9, far ? shoeFar : shoe)
        }
        func arm(_ s: J, _ e: J, _ h: J, far: Bool) {
            line(&c, pose[s], pose[e], 13, far ? shirtFar : shirt)
            line(&c, pose[e], pose[h], 9, far ? skinFar : skin)
            dot(&c, pose[h], 5.5, far ? skinFar : skin)
            dot(&c, pose[s], 6.5, far ? shirtFar : shirt)
        }
        let shoulderMid = P(x: (pose[.shL].x + pose[.shR].x) / 2, y: (pose[.shL].y + pose[.shR].y) / 2)
        let hipMid = P(x: (pose[.hiL].x + pose[.hiR].x) / 2, y: (pose[.hiL].y + pose[.hiR].y) / 2)
        leg(.hiR, .knR, .ftR, .toR, far: isSide)
        if isSide { arm(.shR, .elR, .haR, far: true) }
        if isSide {
            var torso = Path(); torso.move(to: CGPoint(x: hipMid.x, y: hipMid.y))
            let s = pose[.spine], mid = P(x: (hipMid.x + shoulderMid.x) / 2, y: (hipMid.y + shoulderMid.y) / 2)
            torso.addQuadCurve(to: CGPoint(x: shoulderMid.x, y: shoulderMid.y), control: CGPoint(x: 2 * s.x - mid.x, y: 2 * s.y - mid.y))
            c.stroke(torso, with: .color(shirt), style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round))
        } else {
            var torso = Path()
            torso.move(to: CGPoint(x: pose[.shL].x, y: pose[.shL].y)); torso.addLine(to: CGPoint(x: pose[.shR].x, y: pose[.shR].y))
            torso.addLine(to: CGPoint(x: pose[.hiR].x, y: pose[.hiR].y)); torso.addLine(to: CGPoint(x: pose[.hiL].x, y: pose[.hiL].y)); torso.closeSubpath()
            c.fill(torso, with: .color(shirt))
            c.stroke(torso, with: .color(shirt), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
        }
        leg(.hiL, .knL, .ftL, .toL, far: false)
        arm(.shL, .elL, .haL, far: false)
        if !isSide { arm(.shR, .elR, .haR, far: false) }
        let head = pose[.head]
        line(&c, shoulderMid, head, 9, skin)
        dot(&c, head, 15, skin)
        // Hair cap and face marks are rotated about the head centre by the head tilt.
        func rot(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: head.x + x * cos(pose.tilt) - y * sin(pose.tilt), y: head.y + x * sin(pose.tilt) + y * cos(pose.tilt))
        }
        var cap = Path()
        let (a0, a1) = isSide ? (110.0, 320.0) : (180.0, 360.0)
        for (i, a) in stride(from: a0, through: a1, by: 10).enumerated() {
            let v = rot(15 * cos(a * .pi / 180), 15 * sin(a * .pi / 180)); i == 0 ? cap.move(to: v) : cap.addLine(to: v)
        }
        cap.closeSubpath(); c.fill(cap, with: .color(hair))
        let eyes = isSide ? [(7.0, 1.0)] : [(-5.5, 2.0), (5.5, 2.0)]
        for e in eyes { let v = rot(e.0, e.1); c.fill(Path(ellipseIn: CGRect(x: v.x - 1.4, y: v.y - 1.4, width: 2.8, height: 2.8)), with: .color(hair)) }
        if isSide { let v = rot(15, 3); c.fill(Path(ellipseIn: CGRect(x: v.x - 2.5, y: v.y - 2.5, width: 5, height: 5)), with: .color(skin)) }
    }

    // MARK: Hand close-ups

    /// Side view: the near hand bends backward from its wrist while the other hand eases the fingers back.
    private static func wrists(_ c: inout GraphicsContext, angle: Double, mirrored: Bool) {
        if mirrored { c.translateBy(x: 240, y: 0); c.scaleBy(x: -1, y: 1) }
        let wrist = p(78, 118), d = p(cos(angle), sin(angle)), n = p(-d.y, d.x)
        func at(_ o: P, _ along: Double, _ across: Double = 0) -> P { p(o.x + along * d.x + across * n.x, o.y + along * d.y + across * n.y) }
        line(&c, p(-10, 118), p(34, 118), 40, shirt); line(&c, p(34, 118), wrist, 28, skin)
        let tip = at(wrist, 76), palmEnd = at(wrist, 34)
        line(&c, wrist, palmEnd, 32, skin); line(&c, palmEnd, tip, 26, skin)
        line(&c, at(wrist, 6, -12), at(wrist, 34, -26), 12, skin)
        // The helping hand rests on the fingertips and its forearm leaves toward the lower right.
        let contact = at(wrist, 66, 15), helper = at(contact, 0, 26)
        let cuff = p(helper.x + 26, helper.y + 14)
        line(&c, p(cuff.x + 44, cuff.y + 36), cuff, 36, shirtFar)
        line(&c, cuff, helper, 24, skinFar); line(&c, helper, contact, 20, skinFar)
    }
    /// params: finger spread, finger length, thumb angle, thumb length, fist amount (0 open, 1 closed).
    private static func fingers(_ c: inout GraphicsContext, _ v: [Double]) {
        line(&c, p(120, 195), p(120, 150), 36, shirt)
        line(&c, p(120, 172), p(120, 140), 30, skin)
        line(&c, p(120, 138), p(120, 122), 58, skin)
        for i in 0..<4 {
            let k = Double(i) - 1.5, base = p(120 + k * 13.5, 106), a = -Double.pi / 2 + v[0] * k
            let end = p(base.x + v[1] * cos(a), base.y + v[1] * sin(a))
            line(&c, base, end, 15, skinFar); line(&c, base, end, 12, skin)
        }
        let tb = p(92, 132), te = p(tb.x + v[3] * cos(v[2]), tb.y + v[3] * sin(v[2]))
        line(&c, tb, te, 16, skinFar); line(&c, tb, te, 13, skin)
    }
}
