import Foundation

/// Resolved interface language: the stored choice, or the macOS preferred languages for "System Default".
func currentLanguage(defaults: UserDefaults = .standard) -> String {
    AppLanguage.resolve(preference: defaults.string(forKey: "language"), preferredLanguages: Locale.preferredLanguages)
}
func L(_ key: String) -> String {
    let language = currentLanguage()
    let bundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    return NSLocalizedString(key, bundle: bundle, comment: "")
}
func durationText(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(ceil(seconds)))
    return String(format: "%02d:%02d", value / 60, value % 60)
}
