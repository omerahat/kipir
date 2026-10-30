import Foundation

func L(_ key: String) -> String {
    let language = UserDefaults.standard.string(forKey: "language") == "en" ? "en" : "tr"
    let bundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    return NSLocalizedString(key, bundle: bundle, comment: "")
}
func durationText(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(ceil(seconds)))
    return String(format: "%02d:%02d", value / 60, value % 60)
}
