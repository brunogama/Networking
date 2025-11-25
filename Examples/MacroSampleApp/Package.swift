// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "MacroSampleApp",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "MacroSampleApp", targets: ["MacroSampleApp"])
  ],
  dependencies: [
    .package(name: "Networking", path: "../..")
  ],
  targets: [
    .executableTarget(
      name: "MacroSampleApp",
      dependencies: [
        .product(name: "Networking", package: "Networking")
      ]
    )
  ]
)
