// Splits each two-panel source illustration (left = start pose, right = end pose) into two aligned,
// trimmed PNGs inside Kipir/Resources/Assets.xcassets as `exercise-<movement>-start|end` image sets.
// Both halves share one crop rectangle so the figure does not jump between poses.
// Usage (from the repository root):
//   swift Scripts/PrepareExerciseImages.swift generated_images
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let mapping: [(file: String, movement: String)] = [
    ("Two Characters, Different Shoulders.png", "shrug"),
    ("Neutral Office Worker Head Tilt Comparison.png", "neckTilt"),
    ("Two-Panel Chest-Opening Exercise Pose.png", "chest"),
    ("Seated Posture and Cat Stretch Exercise.png", "upperBack"),
    ("Seated Spinal Twist_ Office Chair Stretch.png", "twist"),
    ("Two-Panel Wrist Stretch Guide.png", "wrists"),
    ("Open Palms and Closed Fists.png", "fingers"),
    ("Standing Tall_ Everyday Stretch Pose.png", "calves"),
    ("Marching Men in Teal Shirts.png", "march"),
    ("Side-by-Side Walking Cartoon Man.png", "walk"),
    ("Shoulder Roll Posture Comparison.png", "shoulders"),
]
let outputHeight = 360 // 2x for the ~180 pt exercise card

let source = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "generated_images")
let catalog = URL(fileURLWithPath: "Kipir/Resources/Assets.xcassets")

func load(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}
func rgba(_ image: CGImage) -> (data: [UInt8], width: Int, height: Int) {
    let w = image.width, h = image.height
    var data = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    return (data, w, h)
}
/// Bounding box (top-left origin) of pixels that are clearly not background white.
func contentBox(_ px: (data: [UInt8], width: Int, height: Int), x0: Int, x1: Int) -> CGRect? {
    var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
    for y in 0..<px.height {
        for x in x0..<x1 {
            let i = (y * px.width + x) * 4
            if min(px.data[i], px.data[i + 1], px.data[i + 2]) < 235 {
                minX = min(minX, x - x0); maxX = max(maxX, x - x0); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
    }
    return maxX < 0 ? nil : CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}
func write(_ image: CGImage, name: String) throws {
    let set = catalog.appendingPathComponent(name + ".imageset")
    try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
    let file = set.appendingPathComponent(name + ".png")
    let dest = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { throw NSError(domain: "png", code: 1) }
    let contents = #"{"images":[{"idiom":"universal","filename":"\#(name).png","scale":"2x"}],"info":{"author":"xcode","version":1}}"#
    try contents.write(to: set.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

for (file, movement) in mapping {
    guard let image = load(source.appendingPathComponent(file)) else { print("skip (missing): \(file)"); continue }
    let px = rgba(image)
    // Split at the emptiest column near the middle: an outstretched arm may cross the exact centre.
    func ink(_ x: Int) -> Int {
        (0..<px.height).reduce(0) { n, y in let i = (y * px.width + x) * 4
            return n + (min(px.data[i], px.data[i + 1], px.data[i + 2]) < 235 ? 1 : 0) }
    }
    let half = (px.width * 35 / 100..<px.width * 65 / 100).min { (ink($0), abs($0 - px.width / 2)) < (ink($1), abs($1 - px.width / 2)) }!
    let rightWidth = px.width - half
    guard let a = contentBox(px, x0: 0, x1: half), let b = contentBox(px, x0: half, x1: px.width) else { continue }
    let margin = 24.0
    var box = a.union(b).insetBy(dx: -margin, dy: -margin)
    box = box.intersection(CGRect(x: 0, y: 0, width: Double(min(half, rightWidth)), height: Double(px.height))).integral
    for (index, pose) in ["start", "end"].enumerated() {
        let rect = box.offsetBy(dx: Double(index * half), dy: 0)
        guard let cropped = image.cropping(to: rect) else { continue }
        let scale = Double(outputHeight) / rect.height
        let w = Int((rect.width * scale).rounded()), h = outputHeight
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.interpolationQuality = .high
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: w, height: h))
        try write(ctx.makeImage()!, name: "exercise-\(movement)-\(pose)")
    }
    print("ok: \(movement) crop \(Int(box.width))x\(Int(box.height))")
}
