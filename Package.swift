// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Fluegel",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "FluegelCore", targets: ["FluegelCore"]),
        .executable(name: "FluegelMenu", targets: ["FluegelApp"]),
        .executable(name: "fluegel", targets: ["FluegelCLI"]),
    ],
    targets: [
        .target(name: "FluegelCore"),
        .executableTarget(
            name: "FluegelApp",
            dependencies: ["FluegelCore"]
        ),
        .executableTarget(
            name: "FluegelCLI",
            dependencies: ["FluegelCore"]
        ),
        .testTarget(
            name: "FluegelCoreTests",
            dependencies: ["FluegelCore"]
        ),
    ]
)
