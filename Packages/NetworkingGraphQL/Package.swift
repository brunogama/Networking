// swift-tools-version: 6.0
// NetworkingGraphQL - GraphQL extension for Networking

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "NetworkingGraphQL",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(
      name: "NetworkingGraphQL",
      targets: ["NetworkingGraphQL"]
    )
  ],
  dependencies: [
    // Local dependency on Core Networking package
    .package(path: "../Networking"),
    // Swift Syntax for macro implementations
    .package(
      url: "https://github.com/swiftlang/swift-syntax.git",
      from: "600.0.0"
    ),
    // Macro testing
    .package(
      url: "https://github.com/pointfreeco/swift-macro-testing.git",
      from: "0.5.2"
    ),
  ],
  targets: [
    // Main GraphQL library
    .target(
      name: "NetworkingGraphQL",
      dependencies: [
        .product(name: "Networking", package: "Networking"),
        "NetworkingGraphQLMacros",
      ],
      swiftSettings: [
        .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
      ]
    ),

    // GraphQL macro implementations
    .macro(
      name: "NetworkingGraphQLMacros",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),

    // Test target
    .testTarget(
      name: "NetworkingGraphQLTests",
      dependencies: [
        "NetworkingGraphQL",
        "NetworkingGraphQLMacros",
        .product(name: "Networking", package: "Networking"),
        .product(name: "MacroTesting", package: "swift-macro-testing"),
      ]
    ),
  ]
)
