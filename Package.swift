// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Astral",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "AstralCore", targets: ["AstralCore"]),
        .executable(name: "astral", targets: ["Astral"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git",
                 "510.0.0"..<"511.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git",
                 "1.4.0"..<"2.0.0"),
    ],
    targets: [
        .target(
            name: "AstralCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .executableTarget(
            name: "Astral",
            dependencies: [
                "AstralCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "AstralCoreTests",
            dependencies: ["AstralCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
