// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "NetworkingConsumer",
  platforms: [.macOS(.v13)],
  dependencies: [.package(path: "../..")],
  targets: [
    .testTarget(
      name: "NetworkingConsumerTests",
      dependencies: [.product(name: "Networking", package: "Networking")]
    )
  ]
)
