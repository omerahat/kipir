import SwiftUI
import AppKit

@main struct ExerciseVisualEvidence {
    @MainActor static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let movements: [ExerciseDefinition.Movement] = [.shoulders, .chest, .wrists, .calves, .walk]
        func tile(_ movement: ExerciseDefinition.Movement, _ phase: Double, _ dark: Bool) -> some View {
            VStack(spacing: 3) {
                Text(String(format: "%.0f°", phase * 180 / .pi)).font(.system(size: 11))
                Canvas { context, size in
                    let scale = min(size.width / 240, size.height / 180)
                    context.translateBy(x: (size.width - 240 * scale) / 2, y: (size.height - 180 * scale) / 2)
                    context.scaleBy(x: scale, y: scale)
                    ExerciseArtwork.draw(&context, movement: movement, phase: phase, alternateHand: false)
                }.frame(width: 240, height: 180).background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            }.foregroundStyle(dark ? .white : .black).padding(5)
                .background(dark ? Color(nsColor: .windowBackgroundColor) : .white)
                .environment(\.colorScheme, dark ? .dark : .light)
        }
        func save<V: View>(_ view: V, _ name: String) throws {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "render", code: 1) }
            try png.write(to: output.appendingPathComponent(name))
        }
        for movement in movements {
            let sheet = VStack(spacing: 0) {
                ForEach([false, true], id: \.self) { dark in
                    HStack(spacing: 0) {
                        ForEach(0..<6) { i in tile(movement, Double(i) * .pi / 3, dark) }
                    }
                }
            }
            try save(sheet, "\(movement.rawValue).png")
            let frames = output.appendingPathComponent("frames-\(movement.rawValue)", isDirectory: true)
            try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
            for i in 0..<24 {
                try save(tile(movement, Double(i) * .pi / 12, false), "frames-\(movement.rawValue)/\(String(format: "%02d", i)).png")
            }
        }
        let overview = VStack(spacing: 0) {
            ForEach(movements, id: \.rawValue) { movement in
                HStack(spacing: 0) {
                    Text(movement.rawValue).frame(width: 80)
                    ForEach(0..<6) { i in tile(movement, Double(i) * .pi / 3, false).scaleEffect(0.6).frame(width: 150, height: 125) }
                }
            }
        }.background(.white)
        try save(overview, "overview.png")
    }
}
