// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let libraryProducts = [
  "Networking", "NetworkingRuntime", "NetworkingObservability",
  "NetworkingObservabilityOTLP", "NetworkingTesting", "NetworkingSSE",
].map { Product.library(name: $0, targets: [$0]) }

let openTelemetryHTTPExporter: Target.Dependency = .product(
  name: "OpenTelemetryProtocolExporterHTTP",
  package: "opentelemetry-swift"
)
let premiseCore: Target.Dependency = .product(name: "PremiseCore", package: "Premise")
let premiseTesting: Target.Dependency = .product(name: "PremiseTesting", package: "Premise")
let premiseStrategies: Target.Dependency = .product(name: "PremiseStrategies", package: "Premise")
let networkingCore: Target.Dependency = .product(name: "NetworkingCore", package: "NetworkingCore")
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

let package = Package(
  name: "Networking",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: libraryProducts,
  dependencies: [
    .package(path: "../NetworkingCore"),
    // OpenTelemetry for observability
    .package(
      url: "https://github.com/open-telemetry/opentelemetry-swift.git",
      from: "1.10.1"
    ),
    .package(url: "https://github.com/brunogama/Premise.git", from: "1.0.2"),
  ],
  targets: [
    libraryTarget(
      "Networking",
      dependencies: networkingDependencies,
      path: "Sources/Networking",
      exclude: [
        "ValidatedResponse.swift.backup", "Documentation.docc", "Networking.docc",
      ]
    ),
    libraryTarget(
      "NetworkingRuntime",
      dependencies: [networkingCore],
      path: "Sources/NetworkingRuntime"
    ),
    libraryTarget(
      "NetworkingObservability",
      dependencies: [networkingCore, "NetworkingRuntime"],
      path: "Sources/NetworkingObservability"
    ),
    libraryTarget(
      "NetworkingObservabilityOTLP",
      dependencies: [
        networkingCore,
        "NetworkingObservability",
        openTelemetryHTTPExporter,
      ],
      path: "Sources/NetworkingObservabilityOTLP"
    ),
    libraryTarget(
      "NetworkingTesting",
      dependencies: [
        networkingCore,
        "NetworkingRuntime",
        "NetworkingObservability",
      ],
      path: "Sources/NetworkingTesting",
      exclude: ["README.md"]
    ),
    libraryTarget(
      "NetworkingSSE",
      dependencies: [
        networkingCore,
        "NetworkingRuntime",
      ],
      path: "Sources/NetworkingSSE"
    ),
    testTarget(
      "NetworkingRuntimeTests",
      dependencies: runtimeTestDependencies,
      path: "Tests/NetworkingRuntimeTests"
    ),
    testTarget(
      "NetworkingObservabilityTests",
      dependencies: observabilityTestDependencies,
      path: "Tests/NetworkingObservabilityTests"
    ),
    testTarget(
      "NetworkingTestingTests",
      dependencies: testingTestDependencies,
      path: "Tests/NetworkingTestingTests"
    ),
    testTarget(
      "NetworkingSSETests",
      dependencies: sseTestDependencies,
      path: "Tests/NetworkingSSETests"
    ),
    testTarget(
      "NetworkingTests",
      dependencies: [
        "Networking",
        "NetworkingTesting",
      ],
      path: "Tests/NetworkingTests",
      exclude: [".swiftlint.yml", "BDD/INTEGRATION_TEST_AUDIT.md"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
