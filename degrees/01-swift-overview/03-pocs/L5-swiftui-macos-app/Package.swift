// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "L5-swiftui-macos-app",
    platforms: [
        .macOS(.v14)            // SwiftUI @Observable, NavigationStack stable on macOS 14+
    ],
    products: [
        .executable(name: "ChatMacApp", targets: ["ChatMacApp"]),
        .library(name: "ChatAppCore", targets: ["ChatAppCore"])
    ],
    dependencies: [
        .package(path: "../L2-anthropic-client")
    ],
    targets: [
        .target(
            name: "ChatAppCore",
            dependencies: [
                .product(name: "AnthropicClient", package: "L2-anthropic-client")
            ]
        ),
        .executableTarget(
            name: "ChatMacApp",
            dependencies: ["ChatAppCore"]
        ),
        .testTarget(
            name: "ChatAppCoreTests",
            dependencies: ["ChatAppCore"]
        )
    ]
)
