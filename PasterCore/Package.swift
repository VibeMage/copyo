// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PasterCore",
    platforms: [
        .macOS(.v14),
        // tools-version 5.10 的 PackageDescription 还没有 .v18 常量，用版本字符串写法
        .iOS("18.0"),
    ],
    products: [
        .library(name: "PasterCore", targets: ["PasterCore"]),
    ],
    targets: [
        .target(name: "PasterCore"),
        .testTarget(name: "PasterCoreTests", dependencies: ["PasterCore"]),
    ]
)
