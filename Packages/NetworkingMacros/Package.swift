// swift-tools-version: 6.0
// NetworkingMacros - Swift macro implementations for Networking

import PackageDescription
import CompilerPluginSupport

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
      targets: ["NetworkingMacrosPlugin"]
    )
  ],
  dependencies: [
    // MacroTemplateKit helper library (local)
    .package(path: "../MacroTemplateKit"),

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
    // Macro implementation (compiler plugin)
    .macro(
      name: "NetworkingMacrosPlugin",
      dependencies: [
        .product(name: "MacroTemplateKit", package: "MacroTemplateKit"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),

    // Test target
    .testTarget(
      name: "NetworkingMacrosTests",
      dependencies: [
        "NetworkingMacrosPlugin",
        .product(name: "MacroTesting", package: "swift-macro-testing"),
      ]
    ),
  ]
)
