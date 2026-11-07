// swift-tools-version: 6.0
// Networking products and targets. Macro declarations live in their own package.

import PackageDescription


// MARK: - Dependency aliases

let openTelemetryHTTPExporter: Target.Dependency = .product(
  name: "OpenTelemetryProtocolExporterHTTP",
  package: "opentelemetry-swift"
)
let premiseCore: Target.Dependency = .product(name: "PremiseCore", package: "Premise")
let premiseTesting: Target.Dependency = .product(name: "PremiseTesting", package: "Premise")
let premiseStrategies: Target.Dependency = .product(name: "PremiseStrategies", package: "Premise")
let networkingCore: Target.Dependency = .product(name: "NetworkingCore", package: "NetworkingCore")

// MARK: - Target dependency groups

let networkingDependencies: [Target.Dependency] = [
  networkingCore, "NetworkingRuntime", "NetworkingObservability", "NetworkingSSE",
]
let runtimeTestDependencies: [Target.Dependency] = [
  networkingCore, "NetworkingRuntime", "NetworkingTesting", premiseCore, premiseTesting,
  premiseStrategies,
]
let observabilityTestDependencies: [Target.Dependency] = [
  networkingCore, "NetworkingObservability", "NetworkingObservabilityOTLP", "NetworkingRuntime",
  "NetworkingTesting", premiseCore, premiseTesting, premiseStrategies,
]
let testingTestDependencies: [Target.Dependency] = [
  networkingCore, "NetworkingTesting", "NetworkingRuntime", "NetworkingObservability",
]
let sseTestDependencies: [Target.Dependency] = [
  networkingCore, "NetworkingSSE", "NetworkingRuntime",
]

// MARK: - Helpers

func libraryTarget(
  _ name: String,
  dependencies: [Target.Dependency] = [],
  path: String,
  exclude: [String] = []
) -> Target {
  .target(
    name: name,
    dependencies: dependencies,
    path: path,
    exclude: exclude
  )
}

func testTarget(
  _ name: String,
  dependencies: [Target.Dependency],
  path: String,
  exclude: [String] = []
) -> Target {
  .testTarget(name: name, dependencies: dependencies, path: path, exclude: exclude)
}

// MARK: - Products

let networkingLibraryProducts: [Product] = [
  "Networking", "NetworkingRuntime", "NetworkingObservability",
  "NetworkingObservabilityOTLP", "NetworkingTesting", "NetworkingSSE",
].map { Product.library(name: $0, targets: [$0]) }


// MARK: - Package

let package = Package(
  name: "ModernNetworking",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: networkingLibraryProducts,
  dependencies: [
    .package(path: "Packages/NetworkingCore"),
    // OpenTelemetry for observability
    .package(
      url: "https://github.com/open-telemetry/opentelemetry-swift.git",
      from: "1.10.1"
    ),
    .package(url: "https://github.com/brunogama/Premise.git", from: "1.0.2"),
  ],
  targets: [
    // ──────────────────────────────────────────────
    // MARK: Networking library targets
    // ──────────────────────────────────────────────
    libraryTarget(
      "Networking",
      dependencies: networkingDependencies,
      path: "Packages/Networking/Sources/Networking",
      exclude: ["ValidatedResponse.swift.backup"]
    ),
    libraryTarget(
      "NetworkingRuntime",
      dependencies: [networkingCore],
      path: "Packages/Networking/Sources/NetworkingRuntime"
    ),
    libraryTarget(
      "NetworkingObservability",
      dependencies: [networkingCore, "NetworkingRuntime"],
      path: "Packages/Networking/Sources/NetworkingObservability"
    ),
    libraryTarget(
      "NetworkingObservabilityOTLP",
      dependencies: [
        networkingCore,
        "NetworkingObservability",
        openTelemetryHTTPExporter,
      ],
      path: "Packages/Networking/Sources/NetworkingObservabilityOTLP"
    ),
    libraryTarget(
      "NetworkingTesting",
      dependencies: [
        networkingCore,
        "NetworkingRuntime",
        "NetworkingObservability",
      ],
      path: "Packages/Networking/Sources/NetworkingTesting",
      exclude: ["README.md"]
    ),
    libraryTarget(
      "NetworkingSSE",
      dependencies: [networkingCore, "NetworkingRuntime"],
      path: "Packages/Networking/Sources/NetworkingSSE"
    ),

    // ──────────────────────────────────────────────
    // MARK: Networking test targets
    // ──────────────────────────────────────────────
    testTarget(
      "NetworkingRuntimeTests",
      dependencies: runtimeTestDependencies,
      path: "Packages/Networking/Tests/NetworkingRuntimeTests"
    ),
    testTarget(
      "NetworkingObservabilityTests",
      dependencies: observabilityTestDependencies,
      path: "Packages/Networking/Tests/NetworkingObservabilityTests"
    ),
    testTarget(
      "NetworkingTestingTests",
      dependencies: testingTestDependencies,
      path: "Packages/Networking/Tests/NetworkingTestingTests"
    ),
    testTarget(
      "NetworkingSSETests",
      dependencies: sseTestDependencies,
      path: "Packages/Networking/Tests/NetworkingSSETests"
    ),
    testTarget(
      "NetworkingTests",
      dependencies: ["Networking", "NetworkingTesting"],
      path: "Packages/Networking/Tests/NetworkingTests",
      exclude: [".swiftlint.yml", "BDD/INTEGRATION_TEST_AUDIT.md"]
    ),

  ],
  swiftLanguageModes: [.v6]
)
