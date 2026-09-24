# ``Networking``

An HTTP client for Swift 6 applications, built on `URLSession`.

---

## Overview

The `Networking` product reexports the core, runtime, request builder,
middleware, observability, and server-sent event modules. Import `Networking`
for the complete runtime API, or depend on individual products when a target
needs fewer modules. API client macros are in the separate `NetworkingMacros`
product.

`NetworkClient` accepts an `HTTPRequest`, runs request middleware, checks for a
cached response, and calls `URLSession` when needed. Response middleware handles
the result. Error middleware can recover a failed request.

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
function. See <doc:Getting-Started> for package installation and local checks.

---

## Modules

- `NetworkingCore` defines requests, responses, errors, and the `HTTPClient` contract.
- `NetworkingRuntime` implements `NetworkClient`, middleware, and file transfers.
- `NetworkingDSL` builds requests. `NetworkingRuntimeDSL` adds client conveniences.
- `NetworkingObservability` provides tracing and metrics.
- `NetworkingSSE` handles server-sent events.
- `NetworkingTesting` provides test clients and URL protocol helpers.

---

## Guides

- <doc:Getting-Started>
- <doc:Core-Networking>
- <doc:Request-Building>
- <doc:Client-Configuration>
- <doc:Middleware-Guide>
- <doc:Authentication>
- <doc:Error-Handling>
- <doc:Security-Features>
- <doc:Module-Migration>
- <doc:API-Reference>

---

## Supported platforms

The package manifest declares iOS 16, macOS 13, tvOS 16, and watchOS 9 as
minimum deployment versions. The package uses Swift tools version 6.0.
