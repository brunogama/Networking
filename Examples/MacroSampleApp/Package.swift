// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "MacroSampleApp",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(path: "../../")
  ],
  targets: [
    .executableTarget(
      name: "MacroSampleApp",
      dependencies: [
        .product(name: "Networking", package: "ModernNetworking")
      ]
    )
  ]
)
