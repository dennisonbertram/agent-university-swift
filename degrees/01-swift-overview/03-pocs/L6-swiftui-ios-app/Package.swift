// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "L6-swiftui-ios-app",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ChatCoreShared", targets: ["ChatCoreShared"])
    ],
    dependencies: [
        .package(path: "../L2-anthropic-client")
    ],
    targets: [
        .target(
            name: "ChatCoreShared",
            dependencies: [
                .product(name: "AnthropicClient", package: "L2-anthropic-client")
            ]
        ),
        .testTarget(
            name: "ChatCoreSharedTests",
            dependencies: ["ChatCoreShared"]
        )
    ]
)
