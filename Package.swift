// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StepAside",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "StepAsideCore", targets: ["StepAsideCore"]),
        .executable(name: "StepAside", targets: ["StepAside"]),
    ],
    targets: [
        .target(name: "StepAsideCore"),
        .executableTarget(
            name: "StepAside",
            dependencies: ["StepAsideCore"],
            exclude: ["Resources"]
        ),
        .testTarget(name: "StepAsideCoreTests", dependencies: ["StepAsideCore"]),
    ]
)
