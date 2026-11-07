// swift-tools-version: 6.0
// Distribution manifest for the public Networking products.

import PackageDescription

private let networkingCore: Target.Dependency = .product(
  name: "NetworkingCore",
  package: "NetworkingCore"
)
private let openTelemetryHTTPExporter: Target.Dependency = .product(
  name: "OpenTelemetryProtocolExporterHTTP",
  package: "opentelemetry-swift"
)
private let premiseCore: Target.Dependency = .product(name: "PremiseCore", package: "Premise")
private let premiseStrategies: Target.Dependency = .product(
  name: "PremiseStrategies",
  package: "Premise"
)
private let premiseTesting: Target.Dependency = .product(name: "PremiseTesting", package: "Premise")

let package = Package(
  name: "Networking",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(name: "Networking", targets: ["Networking"]),
    .library(name: "NetworkingRuntime", targets: ["NetworkingRuntime"]),
    .library(name: "NetworkingObservability", targets: ["NetworkingObservability"]),
    .library(name: "NetworkingObservabilityOTLP", targets: ["NetworkingObservabilityOTLP"]),
    .library(name: "NetworkingTesting", targets: ["NetworkingTesting"]),
    .library(name: "NetworkingSSE", targets: ["NetworkingSSE"]),
  ],
  dependencies: [
    .package(path: "Packages/NetworkingCore"),
    .package(
      url: "https://github.com/open-telemetry/opentelemetry-swift.git",
      from: "1.10.1"
    ),
    .package(url: "https://github.com/brunogama/Premise.git", from: "1.0.2"),
  ],
  targets: [
    .target(
      name: "NetworkingRuntime",
      dependencies: [networkingCore],
      path: "Packages/Networking/Sources/NetworkingRuntime"
    ),
    .target(
      name: "NetworkingObservability",
      dependencies: [networkingCore, "NetworkingRuntime"],
      path: "Packages/Networking/Sources/NetworkingObservability"
    ),
    .target(
      name: "NetworkingObservabilityOTLP",
      dependencies: [
        networkingCore,
        "NetworkingObservability",
        openTelemetryHTTPExporter,
      ],
      path: "Packages/Networking/Sources/NetworkingObservabilityOTLP"
    ),
    .target(
      name: "NetworkingTesting",
      dependencies: [
        networkingCore,
        "NetworkingRuntime",
        "NetworkingObservability",
      ],
      path: "Packages/Networking/Sources/NetworkingTesting",
      exclude: ["README.md"]
    ),
    .target(
      name: "NetworkingSSE",
      dependencies: [networkingCore, "NetworkingRuntime"],
      path: "Packages/Networking/Sources/NetworkingSSE"
    ),
    .target(
      name: "Networking",
      dependencies: [
        networkingCore,
        "NetworkingRuntime",
        "NetworkingObservability",
        "NetworkingSSE",
      ],
      path: "Packages/Networking/Sources/Networking",
      exclude: [
        "Documentation.docc",
        "Networking.docc",
        "ValidatedResponse.swift.backup",
      ]
    ),
    .testTarget(
      name: "NetworkingRuntimeTests",
      dependencies: [
        networkingCore,
        "NetworkingRuntime",
        "NetworkingTesting",
        premiseCore,
        premiseStrategies,
        premiseTesting,
      ],
      path: "Packages/Networking/Tests/NetworkingRuntimeTests"
    ),
    .testTarget(
      name: "NetworkingObservabilityTests",
      dependencies: [
        networkingCore,
        "NetworkingObservability",
        "NetworkingObservabilityOTLP",
        "NetworkingRuntime",
        "NetworkingTesting",
        premiseCore,
        premiseStrategies,
        premiseTesting,
      ],
      path: "Packages/Networking/Tests/NetworkingObservabilityTests"
    ),
    .testTarget(
      name: "NetworkingTestingTests",
      dependencies: [
        networkingCore,
        "NetworkingTesting",
        "NetworkingRuntime",
        "NetworkingObservability",
      ],
      path: "Packages/Networking/Tests/NetworkingTestingTests"
    ),
    .testTarget(
      name: "NetworkingSSETests",
      dependencies: [networkingCore, "NetworkingSSE", "NetworkingRuntime"],
      path: "Packages/Networking/Tests/NetworkingSSETests"
    ),
    .testTarget(
      name: "NetworkingTests",
      dependencies: ["Networking", "NetworkingTesting"],
      path: "Packages/Networking/Tests/NetworkingTests",
      exclude: [".swiftlint.yml", "BDD/INTEGRATION_TEST_AUDIT.md"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
