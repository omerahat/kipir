import AppKit
import Foundation

// Local vector artwork; no external assets or tools.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let catalog = root.appendingPathComponent("Kipir/Resources/Assets.xcassets")
let output = catalog.appendingPathComponent("AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let factor = CGFloat(pixels) / 1024
        let transform = NSAffineTransform(); transform.scale(by: factor); transform.concat()
        NSColor(calibratedRed: 0.06, green: 0.48, blue: 0.46, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 220, yRadius: 220).fill()
        NSColor(calibratedRed: 1, green: 0.83, blue: 0.46, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 552, y: 680, width: 142, height: 142)).fill()
        NSColor.white.setStroke()
        let body = NSBezierPath(); body.lineWidth = 78; body.lineCapStyle = .round; body.lineJoinStyle = .round
        body.move(to: NSPoint(x: 290, y: 520)); body.line(to: NSPoint(x: 454, y: 610))
        body.line(to: NSPoint(x: 580, y: 490)); body.line(to: NSPoint(x: 728, y: 505))
        body.move(to: NSPoint(x: 500, y: 555)); body.line(to: NSPoint(x: 436, y: 350)); body.line(to: NSPoint(x: 292, y: 232))
        body.move(to: NSPoint(x: 445, y: 382)); body.line(to: NSPoint(x: 590, y: 320)); body.line(to: NSPoint(x: 668, y: 216))
        body.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon-\(size)@\(scale)x.png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
    }
}
assert(images.count == 10)
let metadata: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("Contents.json"))
try Data("{\"info\":{\"author\":\"xcode\",\"version\":1}}".utf8).write(to: catalog.appendingPathComponent("Contents.json"))
print("Generated 10 Kıpır icon assets.")
