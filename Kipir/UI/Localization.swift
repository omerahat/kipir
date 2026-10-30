import Foundation

func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, comment: "")
}
func durationText(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(ceil(seconds)))
    return String(format: "%02d:%02d", value / 60, value % 60)
}
