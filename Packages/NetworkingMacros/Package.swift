// swift-tools-version: 6.0
// NetworkingMacros - Swift macro implementations for Networking

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "NetworkingMacros",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(
            name: "NetworkingMacros",
            targets: ["NetworkingMacros"]
        ),
    ],
    dependencies: [
        // MacroTemplateKit - Type-safe templating for macro code generation
        .package(
            url: "https://github.com/brunogama/MacroTemplateKit.git",
            from: "0.0.1"
        ),

        // Swift Syntax for macro implementations
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "600.0.0"
        ),
        // Macro testing framework
        .package(
            url: "https://github.com/pointfreeco/swift-macro-testing.git",
            from: "0.5.2"
        ),
    ],
    targets: [
        .target(
            name: "NetworkingMacros",
            dependencies: ["NetworkingMacrosPlugin"],
            path: "Sources/NetworkingMacrosDeclarations"
        ),

        // Macro implementation (compiler plugin)
        .macro(
            name: "NetworkingMacrosPlugin",
            dependencies: [
                .product(name: "MacroTemplateKit", package: "MacroTemplateKit"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "Sources/NetworkingMacros"
        ),

        // Test target
        .testTarget(
            name: "NetworkingMacrosTests",
            dependencies: [
                "NetworkingMacros",
                "NetworkingMacrosPlugin",
                .product(name: "MacroTesting", package: "swift-macro-testing"),
            ]
        ),
    ]
)
