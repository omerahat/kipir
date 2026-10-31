import Foundation

struct Settings: Codable, Equatable {
    var work: TimeInterval = 45 * 60
    var shortBreak: TimeInterval = 2 * 60
    var longBreak: TimeInterval = 5 * 60
    var longEvery = 3
    var afk: TimeInterval = 90
    var snooze: TimeInterval = 10 * 60
    var notifications = true
    var sound = false
    var breakEndSound = false
    var appearance = "system"

    func validated() -> Settings {
        var s = self
        func valid(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
            value.isFinite && range.contains(value) ? value : fallback
        }
        s.work = valid(work, 60...14400, 2700)
        s.shortBreak = valid(shortBreak, 10...1800, 120)
        s.longBreak = valid(longBreak, 10...3600, 300)
        s.afk = valid(afk, 15...600, 90)
        s.snooze = valid(snooze, 60...3600, 600)
        s.longEvery = (1...10).contains(longEvery) ? longEvery : 3
        s.appearance = ["system", "light", "dark"].contains(appearance) ? appearance : "system"
        return s
    }
}

struct DailyStats: Codable, Equatable {
    var day: Date
    var activeSeconds: TimeInterval = 0
    var breaks = 0
}

enum Phase: String, Codable { case working, due, onBreak }
enum WorkStatus: String { case working, idle, paused, meeting, due, onBreak, suspended }
enum SchedulerAction { case startBreak, snooze, skip, togglePause, toggleMeeting, reset }

struct Checkpoint: Codable {
    var activeWork: TimeInterval = 0
    var target: TimeInterval = 2700
    var phase: Phase = .working
    var breakRemaining: TimeInterval = 0
    var breakDuration: TimeInterval = 120
    var completedShorts = 0
    var isLongBreak = false
    var paused = false
    var meeting = false
    var meetingDeadline: Date?
    var snoozed = false
    var dueID: UUID?
    var today: DailyStats

    var isValid: Bool {
        activeWork.isFinite && (0...1_000_000_000).contains(activeWork) &&
        target.isFinite && (0...1_000_003_600).contains(target) &&
        breakRemaining.isFinite && (0...3600).contains(breakRemaining) &&
        breakDuration.isFinite && (10...3600).contains(breakDuration) && breakRemaining <= breakDuration &&
        (0...10).contains(completedShorts) && today.day.timeIntervalSince1970.isFinite &&
        today.activeSeconds.isFinite && (0...172800).contains(today.activeSeconds) &&
        (0...10000).contains(today.breaks) && (phase != .onBreak || breakRemaining > 0)
    }
}

struct NotificationPolicy {
    static func shouldDeliver(enabled: Bool, authorized: Bool, due: UUID?, sent: UUID?) -> Bool {
        enabled && authorized && due != nil && due != sent
    }
}

struct ExerciseDefinition: Identifiable {
    enum Movement: String { case shoulders, chest, wrists, calves, walk }
    let id: Movement
    let duration: Double
    let area: String
    var nameKey: String { "exercise." + id.rawValue }
    var instructionKey: String { nameKey + ".instruction" }
}

enum ExerciseCatalog {
    static func sequence(long: Bool, duration: Double) -> [ExerciseDefinition] {
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
    init(long: Bool, duration: Double, elapsed: Double = 0) {
        exercises = ExerciseCatalog.sequence(long: long, duration: duration)
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

// Missing deadline means legacy indefinite mode; a malformed new field must not wipe a session.
extension Checkpoint {
    private enum CodingKeys: String, CodingKey {
        case activeWork, target, phase, breakRemaining, breakDuration, completedShorts, isLongBreak
        case paused, meeting, meetingDeadline, snoozed, dueID, today
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activeWork = try c.decode(Double.self, forKey: .activeWork)
        target = try c.decode(Double.self, forKey: .target)
        phase = try c.decode(Phase.self, forKey: .phase)
        breakRemaining = try c.decode(Double.self, forKey: .breakRemaining)
        breakDuration = try c.decode(Double.self, forKey: .breakDuration)
        completedShorts = try c.decode(Int.self, forKey: .completedShorts)
        isLongBreak = try c.decode(Bool.self, forKey: .isLongBreak)
        paused = try c.decode(Bool.self, forKey: .paused)
        meeting = try c.decode(Bool.self, forKey: .meeting)
        snoozed = try c.decode(Bool.self, forKey: .snoozed)
        dueID = try c.decodeIfPresent(UUID.self, forKey: .dueID)
        today = try c.decode(DailyStats.self, forKey: .today)
        do { meetingDeadline = try c.decodeIfPresent(Date.self, forKey: .meetingDeadline) }
        catch { meetingDeadline = nil; meeting = false }
    }
}

extension Settings {
    private enum CodingKeys: String, CodingKey {
        case work, shortBreak, longBreak, longEvery, afk, snooze, notifications, sound, breakEndSound, appearance
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        work = try c.decode(Double.self, forKey: .work)
        shortBreak = try c.decode(Double.self, forKey: .shortBreak)
        longBreak = try c.decode(Double.self, forKey: .longBreak)
        longEvery = try c.decode(Int.self, forKey: .longEvery)
        afk = try c.decode(Double.self, forKey: .afk)
        snooze = try c.decode(Double.self, forKey: .snooze)
        notifications = try c.decode(Bool.self, forKey: .notifications)
        sound = try c.decode(Bool.self, forKey: .sound)
        appearance = try c.decode(String.self, forKey: .appearance)
        breakEndSound = (try? c.decodeIfPresent(Bool.self, forKey: .breakEndSound)) ?? false
    }
}
