// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

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
    // Local dependency on NetworkingMacros package
    .package(path: "../NetworkingMacros"),
    // Test dependencies
    .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0"),
    .package(url: "https://github.com/Quick/Quick.git", from: "7.4.0"),
    .package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0"),
  ],
  targets: [
    // Main library target
    .target(
      name: "Networking",
      dependencies: [
        .product(name: "NetworkingMacros", package: "NetworkingMacros"),
      ],
      exclude: [
        // Exclude BDD module - incomplete integration code that depends on Quick/Nimble
        "BDD",
      ],
      swiftSettings: [
        .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
      ]
    ),

    // Test target
    .testTarget(
      name: "NetworkingTests",
      dependencies: [
        "Networking",
        .product(name: "SwiftCheck", package: "SwiftCheck"),
        .product(name: "Quick", package: "Quick"),
        .product(name: "Nimble", package: "Nimble"),
      ]
    ),
  ]
)
