// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "NetworkingConsumer",
  platforms: [.macOS(.v13)],
  dependencies: [.package(name: "Networking", path: "../..")],
  targets: [
    .testTarget(
      name: "NetworkingConsumerTests",
      dependencies: [.product(name: "Networking", package: "Networking")]
    )
  ]
)
