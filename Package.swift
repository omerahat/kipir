// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "KipirCore", platforms: [.macOS(.v14)],
    products: [.library(name: "KipirCore", targets: ["KipirCore"])],
    targets: [.target(name: "KipirCore", path: "Kipir/Core"),
              .testTarget(name: "KipirCoreTests", dependencies: ["KipirCore"], path: "KipirTests")]
)
