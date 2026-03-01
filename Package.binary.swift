// swift-tools-version: 6.0
// Package.binary.swift -- Release manifest for binary macro distribution.
// On tagged releases, CI swaps this file to Package.swift so consumers
// resolve the pre-built NetworkingMacros plugin without swift-syntax.
import PackageDescription

let package = Package(
  name: "Networking",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(
      name: "Networking",
      targets: ["Networking"]
    )
  ],
  dependencies: [],
  targets: [
    // Main library target
    .target(
      name: "Networking",
      dependencies: ["NetworkingMacros"],
      swiftSettings: [
        .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
      ]
    ),

    // Pre-built macro plugin binary.
    // The executable name matches #externalMacro(module: "NetworkingMacros", ...)
    // in Networking/MacroDeclarations.swift.
    .binaryTarget(
      name: "NetworkingMacros",
      url: "https://github.com/brunogama/Networking/releases/download/__VERSION__/NetworkingMacros.artifactbundle.zip",
      checksum: "__CHECKSUM__"
    ),

    // Note: NetworkingTests is excluded from the binary manifest because
    // it depends on swift-macro-testing (which pulls in swift-syntax).
  ]
)
