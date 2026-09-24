# Getting started

Add Networking to a Swift application and send one HTTP request.

---

## Add the package

Add `https://github.com/brunogama/Networking.git` in Xcode's package dependency
editor and select the `Networking` product. The repository has no version tag
yet, so select the `main` branch. Add the `NetworkingMacros` product if you use
API client macros.

For a Swift package, add the repository dependency and the product to your
target.

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
function. `HTTPResponse` has a `status` and an optional `body`. `NetworkClient`
throws `HTTPError` for transport failures and HTTP error statuses.

---

## Continue

<doc:NetworkClient> describes client execution. <doc:RequestBuilding> covers the
request builder, and <doc:MiddlewareOverview> covers middleware.
