// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CopyoCore",
    platforms: [
        .macOS(.v14),
        // tools-version 5.10 的 PackageDescription 还没有 .v18 常量，用版本字符串写法
        .iOS("18.0"),
    ],
    products: [
        .library(name: "CopyoCore", targets: ["CopyoCore"]),
    ],
    targets: [
        .target(name: "CopyoCore"),
        .testTarget(name: "CopyoCoreTests", dependencies: ["CopyoCore"]),
    ]
)
