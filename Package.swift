// swift-tools-version: 6.0
// Monorepo manifest — all products and targets in one package.
// Sub-package manifests under Packages/ are kept for standalone dev/CI.

import CompilerPluginSupport
import PackageDescription

// swiftlint:disable file_length

let strictConcurrencySettings: [SwiftSetting] = [
  .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
]

// MARK: - Dependency aliases

let openTelemetryHTTPExporter: Target.Dependency = .product(
  name: "OpenTelemetryProtocolExporterHTTP",
  package: "opentelemetry-swift"
)
let openTelemetrySDK: Target.Dependency = .product(
  name: "OpenTelemetrySdk",
  package: "opentelemetry-swift"
)
let swiftCheck: Target.Dependency = .product(name: "SwiftCheck", package: "SwiftCheck")

// MARK: - Target dependency groups

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

// MARK: - Products

let networkingLibraryProducts: [Product] = [
  "Networking", "NetworkingCore", "NetworkingRuntime", "NetworkingDSL", "NetworkingRuntimeDSL",
  "NetworkingInterceptorsCompat", "NetworkingObservability", "NetworkingObservabilityOTLP",
  "NetworkingTesting", "NetworkingBDD", "NetworkingSSE",
].map { Product.library(name: $0, targets: [$0]) }

let macroProducts: [Product] = [
  .library(name: "NetworkingMacros", targets: ["NetworkingMacros"])
]

// MARK: - Package

let package = Package(
  name: "ModernNetworking",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: networkingLibraryProducts + macroProducts,
  dependencies: [
    // OpenTelemetry for observability
    .package(
      url: "https://github.com/open-telemetry/opentelemetry-swift.git",
      from: "1.10.1"
    ),
    // Property-based testing
    .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0"),
    // MacroTemplateKit - Type-safe templating for macro code generation
    .package(
      url: "https://github.com/brunogama/MacroTemplateKit.git",
      from: "0.0.1"
    ),
    // Swift Syntax for macro implementations
    .package(
      url: "https://github.com/swiftlang/swift-syntax.git",
      from: "600.0.0"
    ),
    // Macro testing framework
    .package(
      url: "https://github.com/pointfreeco/swift-macro-testing.git",
      from: "0.5.2"
    ),
  ],
  targets: [
    // ──────────────────────────────────────────────
    // MARK: Networking library targets
    // ──────────────────────────────────────────────
    libraryTarget(
      "Networking",
      dependencies: networkingDependencies,
      path: "Packages/Networking/Sources/Networking",
      exclude: ["CLAUDE.md", "ValidatedResponse.swift.backup"]
    ),
    libraryTarget(
      "NetworkingCore",
      path: "Packages/Networking/Sources/NetworkingCore"
    ),
    libraryTarget(
      "NetworkingRuntime",
      dependencies: ["NetworkingCore"],
      path: "Packages/Networking/Sources/NetworkingRuntime"
    ),
    libraryTarget(
      "NetworkingDSL",
      dependencies: ["NetworkingCore"],
      path: "Packages/Networking/Sources/NetworkingDSL"
    ),
    libraryTarget(
      "NetworkingRuntimeDSL",
      dependencies: ["NetworkingDSL", "NetworkingRuntime"],
      path: "Packages/Networking/Sources/NetworkingRuntimeDSL"
    ),
    libraryTarget(
      "NetworkingInterceptorsCompat",
      dependencies: ["NetworkingRuntime"],
      path: "Packages/Networking/Sources/NetworkingInterceptorsCompat"
    ),
    libraryTarget(
      "NetworkingObservability",
      dependencies: ["NetworkingRuntime"],
      path: "Packages/Networking/Sources/NetworkingObservability"
    ),
    libraryTarget(
      "NetworkingObservabilityOTLP",
      dependencies: [
        "NetworkingObservability",
        openTelemetryHTTPExporter,
        openTelemetrySDK,
      ],
      path: "Packages/Networking/Sources/NetworkingObservabilityOTLP"
    ),
    libraryTarget(
      "NetworkingTesting",
      dependencies: [
        "NetworkingRuntime",
        "NetworkingInterceptorsCompat",
        "NetworkingObservability",
      ],
      path: "Packages/Networking/Sources/NetworkingTesting",
      exclude: ["README.md"]
    ),
    libraryTarget(
      "NetworkingBDD",
      dependencies: ["NetworkingRuntime", "NetworkingTesting"],
      path: "Packages/Networking/Sources/NetworkingBDD"
    ),
    libraryTarget(
      "NetworkingSSE",
      dependencies: ["NetworkingCore", "NetworkingRuntime"],
      path: "Packages/Networking/Sources/NetworkingSSE"
    ),

    // ──────────────────────────────────────────────
    // MARK: Networking test targets
    // ──────────────────────────────────────────────
    testTarget(
      "NetworkingCoreTests",
      dependencies: ["NetworkingCore", "NetworkingTesting"],
      path: "Packages/Networking/Tests/NetworkingCoreTests"
    ),
    testTarget(
      "NetworkingRuntimeTests",
      dependencies: runtimeTestDependencies,
      path: "Packages/Networking/Tests/NetworkingRuntimeTests"
    ),
    testTarget(
      "NetworkingDSLTests",
      dependencies: [
        "NetworkingDSL", "NetworkingRuntime", "NetworkingRuntimeDSL", "NetworkingTesting",
      ],
      path: "Packages/Networking/Tests/NetworkingDSLTests"
    ),
    testTarget(
      "NetworkingInterceptorsCompatTests",
      dependencies: interceptorsCompatTestDependencies,
      path: "Packages/Networking/Tests/NetworkingInterceptorsCompatTests"
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
      "NetworkingBDDTests",
      dependencies: ["NetworkingBDD", "NetworkingRuntime", "NetworkingTesting"],
      path: "Packages/Networking/Tests/NetworkingBDDTests"
    ),
    testTarget(
      "NetworkingSSETests",
      dependencies: sseTestDependencies,
      path: "Packages/Networking/Tests/NetworkingSSETests"
    ),
    testTarget(
      "NetworkingTests",
      dependencies: ["Networking", "NetworkingTesting", swiftCheck],
      path: "Packages/Networking/Tests/NetworkingTests",
      exclude: [".swiftlint.yml", "BDD/INTEGRATION_TEST_AUDIT.md", "CLAUDE.md"]
    ),

    // ──────────────────────────────────────────────
    // MARK: Macro targets
    // ──────────────────────────────────────────────
    .target(
      name: "NetworkingMacros",
      dependencies: ["NetworkingMacrosPlugin"],
      path: "Packages/NetworkingMacros/Sources/NetworkingMacrosDeclarations",
      swiftSettings: strictConcurrencySettings
    ),
    .macro(
      name: "NetworkingMacrosPlugin",
      dependencies: [
        .product(name: "MacroTemplateKit", package: "MacroTemplateKit"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ],
      path: "Packages/NetworkingMacros/Sources/NetworkingMacros"
    ),
    .testTarget(
      name: "NetworkingMacrosTests",
      dependencies: [
        "NetworkingMacros",
        "NetworkingMacrosPlugin",
        .product(name: "MacroTesting", package: "swift-macro-testing"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ],
      path: "Packages/NetworkingMacros/Tests/NetworkingMacrosTests"
    ),
  ]
)

// swiftlint:enable file_length
