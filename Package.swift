// swift-tools-version: 6.0
// Development manifest -- builds NetworkingMacros from source (requires swift-syntax).
// For release tags, CI swaps Package.binary.swift into Package.swift so consumers
// resolve a pre-built binary plugin without the swift-syntax dependency.
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
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "510.0.0"..<"700.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.5.2"),
  ],
  targets: [
    // Main library target
    .target(
      name: "Networking",
      dependencies: ["NetworkingMacros"],
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
