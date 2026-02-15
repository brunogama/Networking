// swift-tools-version: 6.0
// NetworkingWebSocket - WebSocket extension for Networking

import PackageDescription

let package = Package(
  name: "NetworkingWebSocket",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(
      name: "NetworkingWebSocket",
      targets: ["NetworkingWebSocket"]
    )
  ],
  dependencies: [
    // Local dependency on Core Networking package
    .package(path: "../Networking"),
  ],
  targets: [
    .target(
      name: "NetworkingWebSocket",
      dependencies: [
        .product(name: "Networking", package: "Networking"),
      ],
      swiftSettings: [
        .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
      ]
    ),
    .testTarget(
      name: "NetworkingWebSocketTests",
      dependencies: ["NetworkingWebSocket"]
    ),
  ]
)
