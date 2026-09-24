# Quick start

Use this guide to build the repository and make one request with the runtime
package. You need a Swift 6 toolchain. On macOS, install Xcode and select its
command-line tools before running Swift Package Manager.

---

## Build the packages

```bash
git clone https://github.com/brunogama/Networking.git
cd Networking
swift build --package-path Packages/Networking -Xswiftc -warnings-as-errors
swift test --package-path Packages/Networking
```

The macro package is separate. Build and test it if you work on API client
macros.

```bash
swift build --package-path Packages/NetworkingMacros -Xswiftc -warnings-as-errors
swift test --package-path Packages/NetworkingMacros
```

The root manifest also declares products and targets for consumers. Use
`--package-path` for repository checks so the results identify the affected
package.

---

## Add Networking to an app

Add `https://github.com/brunogama/Networking.git` in Xcode's package dependency
editor and select the `Networking` product. There is no version tag yet, so
select the `main` branch. If you use API client macros, also select the
`NetworkingMacros` product.

For a package manifest, add the dependency and product to the app target.

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/Networking.git", branch: "main")
],
targets: [
    .executableTarget(
        name: "Example",
        dependencies: [
            .product(name: "Networking", package: "Networking")
        ]
    )
]
```

---

## Send a request

Import `Networking` and create a request with a complete URL.

```swift
import Foundation
import Networking

func loadUsers() async throws -> HTTPResponse {
    guard let url = URL(string: "https://api.example.com/users") else {
        throw URLError(.badURL)
    }

    let request = HTTPRequest(method: .get, url: url)
    return try await NetworkClient().execute(request)
}
```

`loadUsers()` returns an `HTTPResponse`. Read `response.status` for the HTTP
status and `response.body` for the optional body. The example URL is a placeholder;
replace it with an endpoint you control before calling the function.

For client configuration, middleware, and the request builder, use the
[Networking guides](Packages/Networking/Sources/Networking/Networking.docc/Networking.md).
