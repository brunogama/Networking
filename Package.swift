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
    // Local packages for workspace development
    .package(path: "Packages/Networking"),
    .package(path: "Packages/NetworkingWebSocket"),
    .package(path: "Packages/NetworkingGraphQL"),
  ],
  targets: []
)
