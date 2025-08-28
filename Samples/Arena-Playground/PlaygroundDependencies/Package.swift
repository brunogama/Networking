// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PlaygroundDependencies",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
  ],
  products: [
    .library(
      name: "PlaygroundDependencies",
      targets: ["PlaygroundDependencies"]
    )
  ],
  dependencies: [
    .package(name: "Networking", path: "../../../")
  ],
  targets: [
    .target(
      name: "PlaygroundDependencies",
      dependencies: [
        .product(name: "Networking", package: "Networking")
      ]
    ),
    .testTarget(
      name: "PlaygroundDependenciesTests",
      dependencies: ["PlaygroundDependencies"]
    ),
  ]
)
