// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// swiftlint:disable file_length

let strictConcurrencySettings: [SwiftSetting] = [
  .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
]

let libraryProducts = [
  "Networking", "NetworkingCore", "NetworkingRuntime", "NetworkingDSL", "NetworkingRuntimeDSL",
  "NetworkingInterceptorsCompat", "NetworkingObservability", "NetworkingObservabilityOTLP",
  "NetworkingTesting", "NetworkingBDD", "NetworkingSSE",
].map { Product.library(name: $0, targets: [$0]) }

let openTelemetryHTTPExporter: Target.Dependency = .product(
  name: "OpenTelemetryProtocolExporterHTTP",
  package: "opentelemetry-swift"
)
let openTelemetrySDK: Target.Dependency = .product(
  name: "OpenTelemetrySdk",
  package: "opentelemetry-swift"
)
let swiftCheck: Target.Dependency = .product(name: "SwiftCheck", package: "SwiftCheck")
let networkingDependencies: [Target.Dependency] = [
  "NetworkingCore", "NetworkingRuntime", "NetworkingDSL", "NetworkingRuntimeDSL",
  "NetworkingInterceptorsCompat", "NetworkingObservability", "NetworkingSSE",
]
let runtimeTestDependencies: [Target.Dependency] = [
  "NetworkingRuntime", "NetworkingDSL", "NetworkingRuntimeDSL", "NetworkingTesting", swiftCheck,
]
let interceptorsCompatTestDependencies: [Target.Dependency] = [
  "NetworkingInterceptorsCompat", "NetworkingRuntime", "NetworkingDSL", "NetworkingTesting",
  swiftCheck,
]
let observabilityTestDependencies: [Target.Dependency] = [
  "NetworkingObservability", "NetworkingObservabilityOTLP", "NetworkingRuntime", "NetworkingDSL",
  "NetworkingTesting",
]
let testingTestDependencies: [Target.Dependency] = [
  "NetworkingTesting", "NetworkingRuntime", "NetworkingObservability", "NetworkingDSL",
  "NetworkingRuntimeDSL",
]
let sseTestDependencies: [Target.Dependency] = [
  "NetworkingSSE"
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
    exclude: exclude,
    swiftSettings: strictConcurrencySettings
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
    // OpenTelemetry for observability
    .package(
      url: "https://github.com/open-telemetry/opentelemetry-swift.git",
      from: "1.10.1"
    ),
    // Test dependencies
    .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0"),
  ],
  targets: [
    libraryTarget(
      "Networking",
      dependencies: networkingDependencies,
      path: "Sources/Networking",
      exclude: ["CLAUDE.md", "ValidatedResponse.swift.backup"]
    ),
    libraryTarget(
      "NetworkingCore",
      path: "Sources/NetworkingCore"
    ),
    libraryTarget(
      "NetworkingRuntime",
      dependencies: ["NetworkingCore"],
      path: "Sources/NetworkingRuntime"
    ),
    libraryTarget(
      "NetworkingDSL",
      dependencies: ["NetworkingCore"],
      path: "Sources/NetworkingDSL"
    ),
    libraryTarget(
      "NetworkingRuntimeDSL",
      dependencies: [
        "NetworkingDSL",
        "NetworkingRuntime",
      ],
      path: "Sources/NetworkingRuntimeDSL"
    ),
    libraryTarget(
      "NetworkingInterceptorsCompat",
      dependencies: ["NetworkingRuntime"],
      path: "Sources/NetworkingInterceptorsCompat"
    ),
    libraryTarget(
      "NetworkingObservability",
      dependencies: ["NetworkingRuntime"],
      path: "Sources/NetworkingObservability"
    ),
    libraryTarget(
      "NetworkingObservabilityOTLP",
      dependencies: [
        "NetworkingObservability",
        openTelemetryHTTPExporter,
        openTelemetrySDK,
      ],
      path: "Sources/NetworkingObservabilityOTLP"
    ),
    libraryTarget(
      "NetworkingTesting",
      dependencies: [
        "NetworkingRuntime",
        "NetworkingInterceptorsCompat",
        "NetworkingObservability",
      ],
      path: "Sources/NetworkingTesting",
      exclude: ["README.md"]
    ),
    libraryTarget(
      "NetworkingBDD",
      dependencies: [
        "NetworkingRuntime",
        "NetworkingTesting",
      ],
      path: "Sources/NetworkingBDD"
    ),
    libraryTarget(
      "NetworkingSSE",
      dependencies: [
        "NetworkingCore",
        "NetworkingRuntime",
      ],
      path: "Sources/NetworkingSSE"
    ),
    testTarget(
      "NetworkingCoreTests",
      dependencies: [
        "NetworkingCore",
        "NetworkingTesting",
      ],
      path: "Tests/NetworkingCoreTests"
    ),
    testTarget(
      "NetworkingRuntimeTests",
      dependencies: runtimeTestDependencies,
      path: "Tests/NetworkingRuntimeTests"
    ),
    testTarget(
      "NetworkingDSLTests",
      dependencies: [
        "NetworkingDSL",
        "NetworkingRuntime",
        "NetworkingRuntimeDSL",
        "NetworkingTesting",
      ],
      path: "Tests/NetworkingDSLTests"
    ),
    testTarget(
      "NetworkingInterceptorsCompatTests",
      dependencies: interceptorsCompatTestDependencies,
      path: "Tests/NetworkingInterceptorsCompatTests"
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
      "NetworkingBDDTests",
      dependencies: [
        "NetworkingBDD",
        "NetworkingRuntime",
        "NetworkingTesting",
      ],
      path: "Tests/NetworkingBDDTests"
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
        swiftCheck,
      ],
      path: "Tests/NetworkingTests",
      exclude: [".swiftlint.yml", "BDD/INTEGRATION_TEST_AUDIT.md", "CLAUDE.md"]
    ),
  ]
)

// swiftlint:enable file_length
