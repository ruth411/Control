// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Control",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Control", targets: ["Control"])],
    targets: [
        .executableTarget(name: "Control"),
        .testTarget(name: "ControlTests")
    ]
)
