// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PsrShot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PsrShot", targets: ["PsrShot"])
    ],
    targets: [
        .executableTarget(
            name: "PsrShot",
            path: "Sources/PsrShot"
        ),
        .testTarget(
            name: "PsrShotTests",
            dependencies: ["PsrShot"],
            path: "Tests/PsrShotTests"
        )
    ]
)
