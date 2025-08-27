// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PlaygroundDependencies",
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "PlaygroundDependencies",
      targets: ["PlaygroundDependencies"]
    )
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "PlaygroundDependencies"
    ),
    .testTarget(
      name: "PlaygroundDependenciesTests",
      dependencies: ["PlaygroundDependencies"]
    ),
  ]
)

package.dependencies = [
  .package(path: "/Users/bruno/Developer/Inbox/Networking")
]
package.targets = [
  .target(
    name: "PlaygroundDependencies",
    dependencies: [
      .product(name: "Networking", package: "Networking")
    ]
  )
]
package.platforms = [
  .iOS("16.0"),
  .macOS("13.0"),
  .tvOS("16.0"),
  .watchOS("9.0"),
]
