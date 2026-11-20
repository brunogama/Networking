// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "ExtensionConsumer",
  platforms: [.macOS(.v13)],
  dependencies: [
    .package(path: "../../Packages/Networking"),
    .package(path: "../../Packages/NetworkingMacros"),
  ],
  targets: [
    .target(
      name: "ExtensionConsumerAPI",
      dependencies: [
        .product(name: "Networking", package: "Networking"),
        .product(name: "NetworkingMacros", package: "NetworkingMacros"),
      ]
    ),
    .testTarget(
      name: "ExtensionConsumerTests",
      dependencies: [
        "ExtensionConsumerAPI",
        .product(name: "Networking", package: "Networking"),
        .product(name: "NetworkingMacros", package: "NetworkingMacros"),
      ]
    ),
  ]
)
