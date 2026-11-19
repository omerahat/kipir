// Renders production ExerciseArtwork key poses, loop samples and Reduce Motion pairs for every movement.
// Build and run (from the repository root; the output directory is the only argument):
//   swiftc -parse-as-library -o /tmp/exercise-evidence Kipir/Core/Exercises.swift \
//     Kipir/UI/Exercises/ExerciseAnimationView.swift Kipir/UI/Localization.swift Scripts/ExerciseVisualEvidence.swift
//   /tmp/exercise-evidence <output-dir>
// Output per movement: <movement>.png (light and dark rows: every key pose, then 6 loop samples) and
// overview.png (all movements, key poses, light and dark). These are rendered samples, not live playback.
import SwiftUI
import AppKit

@main struct ExerciseVisualEvidence {
    typealias Movement = ExerciseDefinition.Movement
    @MainActor static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        func card(_ dark: Bool, caption: String, _ body: @escaping (inout GraphicsContext) -> Void) -> some View {
            VStack(spacing: 2) {
                Text(caption).font(.system(size: 10))
                Canvas { context, size in
                    let scale = min(size.width / 240, size.height / 180)
                    context.translateBy(x: (size.width - 240 * scale) / 2, y: (size.height - 180 * scale) / 2)
                    context.scaleBy(x: scale, y: scale)
                    body(&context)
                }.frame(width: 300, height: 180).background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            }.foregroundStyle(dark ? .white : .black).padding(4)
        }
        func row(_ movement: Movement, dark: Bool) -> some View {
            HStack(spacing: 0) {
                ForEach(0..<ExerciseArtwork.keyCount(movement), id: \.self) { key in
                    card(dark, caption: "key \(key)") { ExerciseArtwork.drawKey(&$0, movement: movement, key: key, alternateHand: false) }
                }
                ForEach(0..<6, id: \.self) { i in
                    card(dark, caption: "loop \(i)/6") { ExerciseArtwork.draw(&$0, movement: movement, loop: Double(i) / 6, alternateHand: false) }
                }
            }
        }
        func reduceMotion(_ movement: Movement, dark: Bool) -> some View {
            let keys = ExerciseArtwork.stillKeys(movement)
            return HStack(spacing: 0) {
                card(dark, caption: "pose.start") { ExerciseArtwork.drawKey(&$0, movement: movement, key: keys.start, alternateHand: false) }
                card(dark, caption: "pose.end") { ExerciseArtwork.drawKey(&$0, movement: movement, key: keys.end, alternateHand: false) }
                if movement == .wrists {
                    card(dark, caption: "second half (hand switched)") { ExerciseArtwork.drawKey(&$0, movement: movement, key: 1, alternateHand: true) }
                }
            }
        }
        func themed<V: View>(_ view: V, dark: Bool) -> some View {
            view.background(dark ? Color(white: 0.12) : .white).environment(\.colorScheme, dark ? .dark : .light)
        }
        func save<V: View>(_ view: V, _ name: String) throws {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "render", code: 1) }
            try png.write(to: output.appendingPathComponent(name))
        }
        for movement in Movement.allCases {
            let sheet = VStack(spacing: 0) {
                themed(row(movement, dark: false), dark: false)
                themed(row(movement, dark: true), dark: true)
                themed(reduceMotion(movement, dark: false), dark: false)
                themed(reduceMotion(movement, dark: true), dark: true)
            }
            try save(sheet, "\(movement.rawValue).png")
        }
        for dark in [false, true] {
            let overview = VStack(spacing: 0) {
                ForEach(Movement.allCases, id: \.rawValue) { movement in
                    HStack(spacing: 0) {
                        Text(movement.rawValue).font(.system(size: 12)).frame(width: 80)
                        ForEach(0..<ExerciseArtwork.keyCount(movement), id: \.self) { key in
                            card(dark, caption: "") { ExerciseArtwork.drawKey(&$0, movement: movement, key: key, alternateHand: false) }
                        }
                        Spacer(minLength: 0)
                    }.frame(width: 80 + 4 * 308, alignment: .leading)
                }
            }.foregroundStyle(dark ? .white : .black)
            try save(themed(overview, dark: dark), dark ? "overview-dark.png" : "overview-light.png")
        }
    }
}
