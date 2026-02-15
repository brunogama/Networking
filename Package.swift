// swift-tools-version: 6.0
// MVP Workspace: Core Networking + Macros only
// Excludes WebSocket and GraphQL extensions

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
    // MacroTemplateKit (template DSL for macro code generation)
    .package(path: "Packages/MacroTemplateKit"),

    // NetworkingMacros (Swift compiler plugin: @GET, @POST, etc.)
    .package(path: "Packages/NetworkingMacros"),

    // Core Networking (async/await HTTP client with interceptors)
    .package(path: "Packages/Networking"),
  ],
  targets: []
)
