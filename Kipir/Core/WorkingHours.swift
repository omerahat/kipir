import Foundation

/// Optional working-hour window. Minutes are local wall-clock minutes from midnight; `weekdays` uses
/// Calendar weekday numbers (1 = Sunday ... 7 = Saturday). `end < start` denotes a window crossing
/// midnight, attributed to the weekday on which it starts.
struct WorkingHours: Codable, Equatable {
    var enabled = false
    var weekdays: [Int] = [2, 3, 4, 5, 6]
    var start = 9 * 60
    var end = 18 * 60

    func validated() -> WorkingHours {
        var w = self
        let days = Set(weekdays.filter { (1...7).contains($0) })
        w.weekdays = days.isEmpty ? [2, 3, 4, 5, 6] : days.sorted()
        let range = 0..<1440
        if !range.contains(start) || !range.contains(end) || start == end { w.start = 9 * 60; w.end = 18 * 60 }
        return w
    }

    /// Contract (implemented by the scheduler workstream): whether `date` lies inside the window.
    /// Disabled windows always contain every date.
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled else { return true }
        return true
    }
}

extension WorkingHours {
    private enum CodingKeys: String, CodingKey { case enabled, weekdays, start, end }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = (try? c.decodeIfPresent(Bool.self, forKey: .enabled)) ?? false
        weekdays = (try? c.decodeIfPresent([Int].self, forKey: .weekdays)) ?? [2, 3, 4, 5, 6]
        start = (try? c.decodeIfPresent(Int.self, forKey: .start)) ?? 9 * 60
        end = (try? c.decodeIfPresent(Int.self, forKey: .end)) ?? 18 * 60
    }
}
