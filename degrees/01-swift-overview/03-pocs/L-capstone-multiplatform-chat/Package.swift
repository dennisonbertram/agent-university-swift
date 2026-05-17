// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "L-capstone-multiplatform-chat",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ChatCore", targets: ["ChatCore"]),
        .executable(name: "chat-backend", targets: ["chat-backend"]),
        .executable(name: "ChatMacApp", targets: ["ChatMacApp"])
    ],
    dependencies: [
        .package(path: "../L2-anthropic-client"),
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0")
    ],
    targets: [
        // Shared cross-platform library (no Hummingbird dep)
        .target(
            name: "ChatCore",
            dependencies: [
                .product(name: "AnthropicClient", package: "L2-anthropic-client")
            ]
        ),
        // Backend logic as a library so tests can import it
        .target(
            name: "ChatBackendLib",
            dependencies: [
                "ChatCore",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "AnthropicClient", package: "L2-anthropic-client")
            ],
            path: "Sources/chat-backend",
            exclude: ["main.swift"]
        ),
        // Executable: just the entry point
        .executableTarget(
            name: "chat-backend",
            dependencies: [
                "ChatBackendLib",
                "ChatCore",
                .product(name: "AnthropicClient", package: "L2-anthropic-client")
            ],
            path: "Sources/chat-backend",
            sources: ["main.swift"]
        ),
        .executableTarget(
            name: "ChatMacApp",
            dependencies: ["ChatCore"]
        ),
        .testTarget(
            name: "CapstoneTests",
            dependencies: [
                "ChatCore",
                "ChatBackendLib",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird"),
                .product(name: "AnthropicClient", package: "L2-anthropic-client")
            ]
        )
    ]
)
