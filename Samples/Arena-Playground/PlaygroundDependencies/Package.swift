// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PlaygroundDependencies",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
  ],
  products: [
    .library(
      name: "PlaygroundDependencies",
      targets: ["PlaygroundDependencies"]
    )
  ],
  dependencies: [
    .package(
        url: "https://github.com/vadymmarkov/Fakery.git",
        exact: "5.1.0"
    )
  ],
  targets: [
    .target(
      name: "PlaygroundDependencies",
      dependencies: [
        .product(name: "Fakery", package: "Fakery")
      ]
    ),
    .testTarget(
      name: "PlaygroundDependenciesTests",
      dependencies: ["PlaygroundDependencies"]
    ),
  ]
)

for target in package.targets where target.type != .system && target.type != .test {
    target.swiftSettings = target.swiftSettings ?? []
    target.swiftSettings?.append(contentsOf: [
        .unsafeFlags(
            [
                "-enable-testing",
                "-warnings-as-errors",
            ],
            .when(configuration: .debug)
        ),
        .unsafeFlags(
            [
                "-enable-testing",
                "-warnings-as-errors",
            ],
            .when(configuration: .release)
        ),
    ])
}
