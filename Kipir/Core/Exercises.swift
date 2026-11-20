import Foundation

/// Body areas used for focus preference and rotation balance. `whole` is reserved for the long-break walk.
enum BodyArea: String, CaseIterable {
    case neckShoulders, back, hands, legs, whole
}

struct ExerciseDefinition: Identifiable {
    enum Movement: String, CaseIterable {
        case shoulders, chest, wrists, calves, walk
        case neckTilt, shrug, upperBack, twist, fingers, march

        var area: BodyArea {
            switch self {
            case .shoulders, .shrug, .neckTilt: return .neckShoulders
            case .chest, .upperBack, .twist: return .back
            case .wrists, .fingers: return .hands
            case .calves, .march: return .legs
            case .walk: return .whole
            }
        }
        /// Natural length of one visual cycle in seconds (fitted to the real duration by `loopPeriod`).
        var basePeriod: Double {
            switch self {
            case .walk, .march: return 2
            case .wrists, .fingers: return 5
            default: return 6
            }
        }
    }
    let id: Movement
    let duration: Double
    var area: BodyArea { id.area }
    var nameKey: String { "exercise." + id.rawValue }
    var instructionKey: String { nameKey + ".instruction" }

    /// Visual loop length that divides `duration` into an even number of equal cycles, so a halfway
    /// change (wrist hand switch) lands on a loop boundary. Falls back to `basePeriod` for bad input.
    var loopPeriod: Double { ExerciseDefinition.loopPeriod(duration: duration, base: id.basePeriod) }
    static func loopPeriod(duration: Double, base: Double) -> Double {
        guard duration.isFinite, duration > 0, base.isFinite, base > 0 else { return max(1, base.isFinite ? base : 4) }
        let pairs = max(1, (duration / (2 * base)).rounded())
        return max(1, duration / (2 * pairs))
    }
}

/// Body-area preference raw values are part of the persisted Settings contract.
enum ExerciseFocus: String, CaseIterable {
    case all, neckShoulders, back, hands
    var area: BodyArea? {
        switch self {
        case .all: return nil
        case .neckShoulders: return .neckShoulders
        case .back: return .back
        case .hands: return .hands
        }
    }
}

enum ExerciseCatalog {
    typealias Movement = ExerciseDefinition.Movement
    /// Rotating movements per area, in catalog order. The walk is only ever the closing long-break movement.
    /// The first row (shoulders, chest, wrists, calves) is the break-1 sequence of the original guide.
    static let byArea: [(area: BodyArea, items: [Movement])] = [
        (.neckShoulders, [.shoulders, .neckTilt, .shrug]),
        (.back, [.chest, .upperBack, .twist]),
        (.hands, [.wrists, .fingers]),
        (.legs, [.calves, .march]),
    ]
    static var rotating: [Movement] { byArea.flatMap(\.items) }

    /// Contract: deterministic for equal inputs (no randomness). `rotation` comes from the persisted
    /// checkpoint so a restored break rebuilds the identical sequence; `rotation` 0 behaves like 1.
    /// Durations are positive and sum to `duration`; the last movement absorbs the remainder.
    /// Rule: pick ~30 s movements (long breaks: 40% of the time, then a walk for the other 60%); never
    /// repeat a movement inside a break; a break's first movement differs from the previous rotation's;
    /// with `.all` the picks cycle through the body areas starting at a rotating area; any other focus
    /// uses its own area first and fills from the general catalog.
    static func sequence(long: Bool, duration: Double, focus: ExerciseFocus = .all, rotation: Int = 0) -> [ExerciseDefinition] {
        let total = duration.isFinite && duration > 0 ? duration : 1
        let walkShare = long ? 0.6 : 0
        let count = min(rotating.count, max(1, Int((total * (1 - walkShare) / 30).rounded())))
        let movements = pick(count: count, focus: focus, turn: max(0, rotation - 1)) + (long ? [Movement.walk] : [])
        let each = total * (1 - walkShare) / Double(count)
        var used = 0.0
        return movements.enumerated().map { index, movement in
            let length = index == movements.count - 1 ? total - used : each
            used += length
            return ExerciseDefinition(id: movement, duration: length)
        }
    }

    private static func pick(count: Int, focus: ExerciseFocus, turn: Int) -> [Movement] {
        var picked: [Movement] = []
        if let area = focus.area, let own = byArea.first(where: { $0.area == area })?.items {
            let start = turn % own.count
            picked = Array((own[start...] + own[..<start]).prefix(count))
            if picked.count == count { return picked }
        }
        let general = byArea.map { entry in entry.items.filter { !picked.contains($0) } }
        var cursor = Array(repeating: 0, count: general.count)
        let areaStart = turn % general.count
        var step = 0
        while picked.count < count {
            let a = (areaStart + step) % general.count
            step += 1
            let items = general[a]
            guard cursor[a] < items.count else { continue }
            picked.append(items[(turn + cursor[a]) % items.count])
            cursor[a] += 1
        }
        return picked
    }
}

struct ExerciseSequenceController {
    let exercises: [ExerciseDefinition]
    private(set) var index = 0
    private(set) var elapsed: Double = 0
    var current: ExerciseDefinition { exercises[index] }
    var remaining: Double { max(0, current.duration - elapsed) }
    /// Time shown on the countdown. The final movement fills the overall budget; earlier ones never
    /// show more than the break itself has left (e.g. after manual navigation).
    func displayRemaining(breakRemaining: Double) -> Double {
        guard breakRemaining.isFinite else { return remaining }
        let budget = max(0, breakRemaining)
        return index == exercises.count - 1 ? budget : min(remaining, budget)
    }
    init(long: Bool, duration: Double, focus: ExerciseFocus = .all, rotation: Int = 0, elapsed: Double = 0) {
        exercises = ExerciseCatalog.sequence(long: long, duration: duration, focus: focus, rotation: rotation)
        advance(elapsed)
    }
    mutating func advance(_ seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        elapsed += seconds
        while elapsed >= current.duration && index < exercises.count - 1 {
            elapsed -= current.duration
            index += 1
        }
        elapsed = min(elapsed, current.duration)
    }
    mutating func navigate(_ offset: Int) {
        index = min(exercises.count - 1, max(0, index + offset)); elapsed = 0
    }
}

/// The visual clock only re-anchors when it drifts from scheduler-accepted time (for example after
/// an awake gap the scheduler rejected), so normal one-second snapshots never make the figure jump.
func exerciseVisualNeedsResync(visual: Double, accepted: Double, tolerance: Double = 2) -> Bool {
    guard visual.isFinite, accepted.isFinite else { return true }
    return abs(visual - accepted) > tolerance
}

// Visual playback owns no timer and never updates the scheduler.
struct ExerciseVisualClock {
    private(set) var offset: Double
    private(set) var anchor: Double
    private(set) var running: Bool

    func time(at now: Double) -> Double {
        offset + (running ? max(0, now - anchor) : 0)
    }
    mutating func setRunning(_ value: Bool, at now: Double) {
        offset = time(at: now)
        anchor = now
        running = value
    }
}

/// Weight of the end pose (0 = start pose, 1 = end pose) at a loop position. Each pose is held for
/// most of its half of the loop, with a short eased crossfade so the figure never looks doubled
/// for long. `phase` is measured in loops; non-finite input shows the start pose.
func exercisePoseBlend(phase: Double, fade: Double = 0.12) -> Double {
    guard phase.isFinite else { return 0 }
    let f = phase - phase.rounded(.down)
    let fade = min(max(fade, 0.001), 0.5)
    func ease(_ x: Double) -> Double { let t = min(max(x, 0), 1); return t * t * (3 - 2 * t) }
    if f < 0.5 - fade { return 0 }
    if f < 0.5 { return ease((f - (0.5 - fade)) / fade) }
    if f < 1 - fade { return 1 }
    return 1 - ease((f - (1 - fade)) / fade)
}
