import AppKit

/// Menu bar label bitmap: icon in a fixed slot plus text in a fixed slot, as one template image whose size depends
/// only on the style (pre-release Fix 2). Only its contents change between states.
enum StatusLabelImage {
    static func make(symbol: String, text: String?, textSlot: CGFloat, font: NSFont, scale: CGFloat) -> NSImage {
        let width = CGFloat(MenuBarLabelLayout.totalWidth(textSlot: Double(textSlot), iconOnly: text == nil))
        let size = NSSize(width: width, height: 18)
        let image = NSImage(size: size)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(ceil(width * scale)),
                                         pixelsHigh: Int(ceil(size.height * scale)), bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return image }
        // Point size first: the graphics context derives its points-to-pixels scale from it.
        rep.size = size
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return image }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let iconSlot = CGFloat(MenuBarLabelLayout.iconSlot)
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        if let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let s = icon.size
            let fit = min(1, iconSlot / max(s.width, 1), size.height / max(s.height, 1))
            let w = s.width * fit, h = s.height * fit
            icon.draw(in: NSRect(x: (iconSlot - w) / 2, y: (size.height - h) / 2, width: w, height: h))
        }
        if let text {
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            let textSize = (text as NSString).size(withAttributes: attributes)
            let x = iconSlot + CGFloat(MenuBarLabelLayout.gap)
            (text as NSString).draw(in: NSRect(x: x, y: (size.height - textSize.height) / 2,
                                               width: textSlot, height: textSize.height), withAttributes: attributes)
        }
        NSGraphicsContext.restoreGraphicsState()
        image.addRepresentation(rep)
        image.isTemplate = true
        return image
    }
}
