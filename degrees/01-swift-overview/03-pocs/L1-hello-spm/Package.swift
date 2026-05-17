// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "L1-hello-spm",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "hello-spm", targets: ["hello-spm"]),
        .library(name: "Greeter", targets: ["Greeter"])
    ],
    targets: [
        .executableTarget(name: "hello-spm", dependencies: ["Greeter"]),
        .target(name: "Greeter"),
        .testTarget(name: "GreeterTests", dependencies: ["Greeter"])
    ]
)
