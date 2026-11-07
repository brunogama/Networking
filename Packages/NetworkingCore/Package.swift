// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "NetworkingCore",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(name: "NetworkingCore", targets: ["NetworkingCore"])
  ],
  dependencies: [
    .package(url: "https://github.com/brunogama/Premise.git", from: "1.0.2")
  ],
  targets: [
    .target(name: "NetworkingCore"),
    .testTarget(
      name: "NetworkingCoreTests",
      dependencies: [
        "NetworkingCore",
        .product(name: "PremiseCore", package: "Premise"),
        .product(name: "PremiseStrategies", package: "Premise"),
        .product(name: "PremiseTesting", package: "Premise"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
