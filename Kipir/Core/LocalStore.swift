import Foundation

final class LocalStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func loadSettings() -> Settings {
        guard let data = defaults.data(forKey: "settings"),
              let value = try? JSONDecoder().decode(Settings.self, from: data) else { return Settings() }
        return value.validated()
    }
    func loadCheckpoint() -> Checkpoint? {
        guard let data = defaults.data(forKey: "checkpoint"),
              let value = try? JSONDecoder().decode(Checkpoint.self, from: data), value.isValid else { return nil }
        return value
    }
    func save(_ settings: Settings) {
        if let data = try? JSONEncoder().encode(settings.validated()) { defaults.set(data, forKey: "settings") }
    }
    func save(_ checkpoint: Checkpoint) {
        guard checkpoint.isValid, let data = try? JSONEncoder().encode(checkpoint) else { return }
        defaults.set(data, forKey: "checkpoint")
    }
}
