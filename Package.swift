// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "dev-toolbox-mcp",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../DevToolBoxCore")
    ],
    targets: [
        .target(
            name: "DevToolBoxMCP",
            dependencies: [.product(name: "DevToolBoxCore", package: "DevToolBoxCore")]
        ),
        .executableTarget(
            name: "dev-toolbox-mcp",
            dependencies: ["DevToolBoxMCP"]
        ),
        .testTarget(
            name: "DevToolBoxMCPTests",
            dependencies: ["DevToolBoxMCP"]
        )
    ]
)
