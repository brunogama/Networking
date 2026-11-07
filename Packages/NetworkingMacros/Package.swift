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
    )
  ],
  dependencies: [
    // Runtime products used by compile-and-execute integration tests.
    .package(path: "../Networking"),
    .package(path: "../NetworkingCore"),

    // Swift Syntax for macro implementations
    .package(
      url: "https://github.com/swiftlang/swift-syntax.git",
      from: "600.0.0"
    ),
  ],
  targets: [
    .target(
      name: "NetworkingMacros",
      dependencies: [
        "NetworkingMacrosPlugin",
        .product(name: "NetworkingCore", package: "NetworkingCore"),
      ],
      path: "Sources/NetworkingMacrosDeclarations"
    ),

    // Macro implementation (compiler plugin)
    .macro(
      name: "NetworkingMacrosPlugin",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
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
        .product(name: "Networking", package: "Networking"),
        .product(name: "NetworkingTesting", package: "Networking"),
        .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
