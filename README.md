# Networking

A Swift 6 HTTP library built on URLSession. Requests are values; middleware owns
its state; scoped request tickets provide cancellation and a single result.

---

## Supported platforms

iOS 16, macOS 13, tvOS 16, and watchOS 9 or later. The package requires Swift 6.
The native traffic inspector is available on iOS and macOS.

Add `https://github.com/brunogama/Networking.git` as a Swift package dependency
from version `2.0.0`, then link the `Networking` product to your target:

```swift
dependencies: [
  .package(
    url: "https://github.com/brunogama/Networking.git",
    from: "2.0.0"
  ),
],
targets: [
  .target(
    name: "YourApp",
    dependencies: [
      .product(name: "Networking", package: "networking"),
    ]
  ),
]
```

Place the package in your manifest's `dependencies` and the product in your
application target's `dependencies`. In Xcode, add the same repository URL,
select version `2.0.0`, and link the `Networking` product. The optional macro
package lives at `Packages/NetworkingMacros`; it is not independently published.

### Opt-in binary distribution

A release also provides `Package.binary.swift` and XCFramework ZIP assets for
`NetworkingCore`, `NetworkingRuntime`, `NetworkingObservability`,
`NetworkingSSE`, and `Networking`. To opt in, download
`Package.binary.swift`, save it as `Package.swift` in a separate local package,
and add it by path. SwiftPM downloads and checksum-verifies the referenced ZIPs.
`NetworkingTesting` and `NetworkingObservabilityOTLP` remain source-only.

---

## Requests and shared configuration

```swift
import Foundation
import Networking

guard let url = URL(string: "https://api.example.com/users") else {
  throw URLError(.badURL)
}
let diagnostics = NetworkDiagnostics()
let client = NetworkClient(
  middleware: HTTPMiddleware(),
  configuration: .init(timeout: 15, diagnostics: diagnostics)
)
let request = HTTPRequest(method: .get, url: url)
let response = try await client.execute(request)
```

`NetworkClient.Configuration` also accepts response size limits. Its `baseURL`
property resolves relative URLs using Foundation URL resolution, and
`defaultHeaders` supplies values that request-specific headers can override.

Create a `JSONCodec` once at the application's composition root and reuse it
for encoding and decoding. Configuration is applied before the codec is shared;
the mutable Foundation coders are not exposed.

```swift
var coding = JSONCodec.Configuration()
coding.dateEncoding = .iso8601
coding.dateDecoding = .iso8601
let codec = JSONCodec(configuration: coding)
let body = try codec.encode(["message": "hello"])
```

Reuse an injected `KeychainService` and `KeychainTokenProvider` for authentication.
Credential values are read from Keychain rather than cached between reads.

---

## Cancellation and diagnostics

```swift
let response = try await client.withRequest(request) { ticket in
  try await ticket.response()
}
```

The noncopyable ticket is consumed by `response()` or `cancel()`. Its shareable
`cancellation` handle can cancel an operation while the response is awaited.
Leaving the scope cancels and joins unfinished child tasks.

Present `NetworkInspector(diagnostics: diagnostics)` in a debug view. The recorder
captures URLSession attempts, redirects, connection reuse and timings, and OSLog
events. Secret headers and query values are redacted; body capture is opt-in.

See [request lifecycle](docs/request-lifecycle.md) for ownership and privacy limits.

---

## Optional capabilities

- `HTTPMiddleware` supplies ordered request, response, and error stages.
- `AuthenticationMiddleware` injects credentials and handles refresh.
- `RetryMiddleware` retries eligible failures with capped exponential delays.
- `CachingMiddleware` supports opt-in memory, disk, or hybrid storage and revalidation.
- `executeBatch` runs an array of requests using bounded child tasks.
- File transfer and server-sent event APIs retain real URLSession transport support.
- `TracingMiddleware` and the separate `NetworkingObservabilityOTLP` product provide
  optional tracing and explicit awaited telemetry export.

Use a separate transport client for retry, authentication recovery, and prefetch
middleware. Avoid injecting the outer client back into its own middleware.

---

## Generated clients

```swift
import Networking
import NetworkingMacros

@API(baseURL: .absolute("https://api.example.com"))
protocol UserAPI {
  @GET(.path("/users/{id}"))
  func user(id: String) async throws -> User
}

let api: any UserAPI = UserAPIFactory.make(client: client, codec: codec)
```

The application supplies the `User` model. Supported annotations are `@API`,
HTTP methods, `@Body`, `@Headers`, `@DefaultHeaders`, and `@Timeout`.
Generated clients retain the injected codec and client.

---

## Breaking migration

Request/configuration builders, response chaining, compatibility interceptors,
BDD infrastructure, simulated transfer controls, and the old analytics/error
advice layers have been removed. Their replacement is ordinary request values,
middleware arrays, Swift Testing, and native diagnostics.

See [the migration guide](docs/api-simplification.md). This redesign does not add
an HTTP memoizer or custom header/body encryption protocol. TLS already protects
headers and bodies in transit; application payload encryption needs a protocol
agreed with the server.

---

## Development

```bash
swift build --package-path Packages/Networking
swift test --package-path Packages/Networking --filter RequestTicketTests
swift test --package-path Packages/NetworkingMacros
swift test --package-path Fixtures/NetworkingConsumer
swift test --package-path Fixtures/ExtensionConsumer
```

Run the relevant focused tests and the repository's explicit-file `swift-style`
gate after changes. See `AGENTS.md` for validation and ownership rules.

The library is available under the MIT license.
