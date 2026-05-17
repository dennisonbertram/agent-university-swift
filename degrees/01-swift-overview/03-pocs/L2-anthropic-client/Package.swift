// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "L2-anthropic-client",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "AnthropicClient", targets: ["AnthropicClient"])
    ],
    targets: [
        .target(name: "AnthropicClient"),
        .testTarget(name: "AnthropicClientTests", dependencies: ["AnthropicClient"])
    ]
)
