// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MuscleLoadCore",
    products: [
        .library(name: "MuscleLoadCore", targets: ["MuscleLoadCore"])
    ],
    targets: [
        .target(name: "MuscleLoadCore"),
        .testTarget(name: "MuscleLoadCoreTests", dependencies: ["MuscleLoadCore"])
    ]
)
