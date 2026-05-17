// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "L3-cli-chat",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "chat", targets: ["chat"]),
        .library(name: "ChatCore", targets: ["ChatCore"])
    ],
    dependencies: [
        .package(path: "../L2-anthropic-client"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "ChatCore",
            dependencies: [
                .product(name: "AnthropicClient", package: "L2-anthropic-client")
            ]
        ),
        .executableTarget(
            name: "chat",
            dependencies: [
                "ChatCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "ChatCoreTests",
            dependencies: [
                "ChatCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
