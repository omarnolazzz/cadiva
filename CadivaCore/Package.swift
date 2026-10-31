// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CadivaCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CadivaCore", targets: ["CadivaCore"]),
    ],
    targets: [
        .target(name: "CadivaCore"),
        .testTarget(name: "CadivaCoreTests", dependencies: ["CadivaCore"]),
    ]
)
