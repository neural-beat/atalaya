// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Atalaya",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.7.0")
    ],
    targets: [
        .executableTarget(
            name: "Atalaya",
            dependencies: [.product(name: "Citadel", package: "Citadel")],
            path: "Sources/Atalaya"
        ),
        .testTarget(name: "AtalayaTests", dependencies: ["Atalaya"])
    ]
)
