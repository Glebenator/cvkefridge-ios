// swift-tools-version: 6.2
import PackageDescription

// The product rules of the iOS app. They use Foundation only, so they also build and run their tests on Linux.
let package = Package(
    name: "CVKEFridgeCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "CVKEFridgeCore", targets: ["CVKEFridgeCore"]),
        .library(name: "CVKEFridgeFeatures", targets: ["CVKEFridgeFeatures"]),
    ],
    targets: [
        .target(name: "CVKEFridgeCore"),
        .testTarget(name: "CVKEFridgeCoreTests", dependencies: ["CVKEFridgeCore"]),
        // The rules of the app that are above the core: the port of the plain Kotlin of the Android app module.
        .target(name: "CVKEFridgeFeatures", dependencies: ["CVKEFridgeCore"]),
        .testTarget(
            name: "CVKEFridgeFeaturesTests",
            dependencies: ["CVKEFridgeFeatures"],
            resources: [.copy("Resources")]
        ),
    ]
)
