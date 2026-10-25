// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PowerBar",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic (settings, smoothing, macmon JSON), testable without AppKit.
        .target(name: "PowerBarCore"),
        // The menu bar app itself.
        .executableTarget(name: "PowerBar", dependencies: ["PowerBarCore"]),
        .testTarget(name: "PowerBarCoreTests", dependencies: ["PowerBarCore"]),
    ]
)
