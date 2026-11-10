// swift-tools-version: 6.2
import PackageDescription

// The product rules of the iOS app. They use Foundation only, so they also build and run their tests on Linux.
let package = Package(
    name: "CVKEFridgeCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [.library(name: "CVKEFridgeCore", targets: ["CVKEFridgeCore"])],
    targets: [
        .target(name: "CVKEFridgeCore"),
        .testTarget(name: "CVKEFridgeCoreTests", dependencies: ["CVKEFridgeCore"]),
    ]
)
