// swift-tools-version: 6.0
// Workspace manifest for ModernNetworking monorepo
// Each package should be consumed directly from Packages/ subdirectories

import PackageDescription

let package = Package(
  name: "ModernNetworking",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [],
  dependencies: [
    // CRITICAL: List packages in dependency order (leaf nodes first)

    // MacroTemplateKit FIRST (no dependencies on other packages)
    .package(path: "Packages/MacroTemplateKit"),

    // NetworkingMacros SECOND (depends on MacroTemplateKit)
    .package(path: "Packages/NetworkingMacros"),

    // Core Networking THIRD (depends on NetworkingMacros)
    .package(path: "Packages/Networking"),

    // Extensions LAST (depend on Core Networking)
    .package(path: "Packages/NetworkingWebSocket"),
    .package(path: "Packages/NetworkingGraphQL"),
  ],
  targets: []
)
