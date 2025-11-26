// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
  name: "Networking",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(
      name: "Networking",
      targets: ["Networking"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.5.2"),
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
  ],
  targets: [
    // Main library target
    .target(
      name: "Networking",
      dependencies: [
        "NetworkingMacros",
        .product(name: "Crypto", package: "swift-crypto"),
      ],
      swiftSettings: [
        .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
      ]
    ),

    // Macro implementations
    .macro(
      name: "NetworkingMacros",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),

    // Test target
    .testTarget(
      name: "NetworkingTests",
      dependencies: [
        "Networking",
        .product(name: "MacroTesting", package: "swift-macro-testing"),
      ]
    ),
  ]
)
