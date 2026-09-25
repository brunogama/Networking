# ``Networking``

A Swift 6 HTTP client built on `URLSession`.

---

## Overview

The `Networking` product reexports the core, runtime, request builder, runtime
DSL, observability, server-sent event, and compatibility interceptor modules.
Import `Networking` for the complete runtime API, or use individual products for
a smaller target.
API client macros are available through the separate `NetworkingMacros` product.

`NetworkClient` applies request middleware, checks for a cached response, and
calls `URLSession` when needed. Response middleware processes the result, while
error middleware can recover a failed request.

---

## Make a request

```swift
import Foundation
import Networking

func fetchUsers() async throws -> HTTPResponse {
    guard let url = URL(string: "https://api.example.com/users") else {
        throw URLError(.badURL)
    }

    let request = HTTPRequest(method: .get, url: url)
    return try await NetworkClient().execute(request)
}
```

Replace the example URL with an endpoint you control before calling the
function. See <doc:GettingStarted> for installation.

---

## Guides

- <doc:HTTPPrimitives>
- <doc:NetworkClient>
- <doc:RequestBuilding>
- <doc:ClientConfiguration>
- <doc:HTTPMethods>
- <doc:RequestComponents>
- <doc:ConditionalRequests>
- <doc:MiddlewareOverview>
- <doc:MIDDLEWARE_DOCUMENTATION>
- <doc:ADVANCED_USAGE>
- <doc:SWIFT_6_FEATURES>
- <doc:TESTING_GUIDE>
- <doc:ARCHITECTURE_GUIDE>
- <doc:MIGRATION_GUIDE>
- <doc:API_REFERENCE>
- <doc:FLUENT_DSL_DOCUMENTATION>

---

## Supported platforms

The package manifest declares iOS 16, macOS 13, tvOS 16, and watchOS 9 as
minimum deployment versions. The package uses Swift tools version 6.0.
