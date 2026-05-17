// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "L4-hummingbird-tool-service",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "tool-server", targets: ["tool-server"]),
        .library(name: "ToolService", targets: ["ToolService"])
    ],
    dependencies: [
        .package(path: "../L2-anthropic-client"),
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "ToolService",
            dependencies: [
                .product(name: "AnthropicClient", package: "L2-anthropic-client"),
                .product(name: "Hummingbird", package: "hummingbird")
            ]
        ),
        .executableTarget(
            name: "tool-server",
            dependencies: ["ToolService"]
        ),
        .testTarget(
            name: "ToolServiceTests",
            dependencies: [
                "ToolService",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTesting", package: "hummingbird")
            ]
        )
    ]
)
