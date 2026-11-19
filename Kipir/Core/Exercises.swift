import Foundation

struct ExerciseDefinition: Identifiable {
    enum Movement: String { case shoulders, chest, wrists, calves, walk }
    let id: Movement
    let duration: Double
    let area: String
    var nameKey: String { "exercise." + id.rawValue }
    var instructionKey: String { nameKey + ".instruction" }
}

/// Body-area preference raw values are part of the persisted Settings contract.
enum ExerciseFocus: String, CaseIterable {
    case all, neckShoulders, back, hands
}

enum ExerciseCatalog {
    /// Contract: deterministic for equal inputs. `rotation` comes from the persisted checkpoint so a
    /// restored break rebuilds the identical sequence. Durations must sum to `duration`.
    static func sequence(long: Bool, duration: Double, focus: ExerciseFocus = .all, rotation: Int = 0) -> [ExerciseDefinition] {
        let movements: [ExerciseDefinition.Movement] = long ? [.shoulders, .chest, .wrists, .calves, .walk] : [.shoulders, .chest, .wrists, .calves]
        let areas = ["shoulders", "chest", "wrists", "legs", "whole"]
        return movements.enumerated().map { index, movement in
            ExerciseDefinition(id: movement, duration: (index == 4 ? 180 : 30) * duration / (long ? 300 : 120), area: areas[index])
        }
    }
}

struct ExerciseSequenceController {
    let exercises: [ExerciseDefinition]
    private(set) var index = 0
    private(set) var elapsed: Double = 0
    var current: ExerciseDefinition { exercises[index] }
    var remaining: Double { max(0, current.duration - elapsed) }
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
