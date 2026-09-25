# Getting started

Add Networking to a Swift application and send one HTTP request.

---

## Add the package

Add `https://github.com/brunogama/Networking.git` in Xcode's package dependency
editor. Select the `Networking` product for your app target. The repository has
no version tag yet, so select the `main` branch. The optional macro product is
named `NetworkingMacros`.

For a Swift package, add the repository dependency and the `Networking` product
to your target.

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

Import `Networking` and pass an `HTTPRequest` to `NetworkClient`.

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

Replace the example URL with an endpoint you control before calling the
function. The returned `HTTPResponse` has a `status` and an optional `body`.
`NetworkClient` throws `HTTPError` for transport failures and HTTP error
statuses.

---

## Build this repository

Run checks against the package you changed. Use both sets when you change
shared repository configuration.

```bash
swift build --package-path Packages/Networking -Xswiftc -warnings-as-errors
swift test --package-path Packages/Networking
swift build --package-path Packages/NetworkingMacros -Xswiftc -warnings-as-errors
swift test --package-path Packages/NetworkingMacros
```

For configuration and middleware, continue with <doc:Client-Configuration> and
<doc:Middleware-Guide>. <doc:Request-Building> describes the request builder.
