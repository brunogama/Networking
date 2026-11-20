// swift-tools-version: 6.2

import Foundation
import PackageDescription

let benchmarksEnabled =
  ProcessInfo.processInfo.environment["NETWORKING_BUILD_BENCHMARKS"] == "1"
let benchmarkProducts: [Product] =
  benchmarksEnabled
  ? [
    .executable(
      name: "NetworkingBenchmarks",
      targets: ["NetworkingBenchmarks"]
    )
  ]
  : []
let benchmarkDependencies: [Package.Dependency] =
  benchmarksEnabled
  ? [.package(path: "../Packages/Networking")]
  : []
let benchmarkTargets: [Target] =
  benchmarksEnabled
  ? [
    .target(
      name: "NetworkingBenchmarksCore",
      dependencies: [.product(name: "Networking", package: "Networking")],
      path: "NetworkingBenchmarksCore"
    ),
    .executableTarget(
      name: "NetworkingBenchmarks",
      dependencies: ["NetworkingBenchmarksCore"],
      path: "NetworkingBenchmarks",
      exclude: ["README.md"]
    ),
    .testTarget(
      name: "NetworkingBenchmarksTests",
      dependencies: ["NetworkingBenchmarksCore"],
      path: "NetworkingBenchmarksTests"
    ),
  ]
  : []

let package = Package(
  name: "NetworkingBenchmarks",
  platforms: [.macOS(.v13)],
  products: benchmarkProducts,
  dependencies: benchmarkDependencies,
  targets: benchmarkTargets,
  swiftLanguageModes: [.v6]
)
