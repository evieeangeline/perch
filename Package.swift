// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Perch",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Perch",
            path: "Sources/Perch",
            resources: [
                .copy("Resources/StatusBarIcon.png"),
                .copy("Resources/Perchie.png")
            ]
        ),
        .testTarget(
            name: "PerchTests",
            dependencies: ["Perch"],
            path: "Tests/PerchTests"
        )
    ]
)
