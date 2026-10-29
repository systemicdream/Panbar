// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Panbar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PanbarCore", targets: ["PanbarCore"]),
        .executable(name: "panbar-cli", targets: ["panbar-cli"]),
    ],
    targets: [
        .target(name: "PanbarCore"),
        .executableTarget(name: "panbar-cli", dependencies: ["PanbarCore"]),
        .testTarget(name: "PanbarCoreTests", dependencies: ["PanbarCore"]),
    ]
)
