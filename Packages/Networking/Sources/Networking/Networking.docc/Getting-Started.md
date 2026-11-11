# Getting Started

Construct requests directly and reuse the client and codec that serve your application.

---

## Add the package

Add this repository through Swift Package Manager and select the `Networking`
product. Import `NetworkingTesting` only from a test target that explicitly
includes that product. Add `NetworkingObservabilityOTLP` separately when an
OTLP collector is part of the application.

---

## Execute and decode

The following code runs inside an asynchronous throwing operation. Create the
client and codec once at the application's composition root, then inject them
into features that make requests.

```swift
import Foundation
import Networking

struct User: Codable, Sendable {
  let id: String
  let name: String
}

var coding = JSONCodec.Configuration()
coding.dateEncoding = .iso8601
coding.dateDecoding = .iso8601
let codec = JSONCodec(configuration: coding)

let client = NetworkClient(
  middleware: HTTPMiddleware(),
  configuration: .init(timeout: 15, maximumResponseBytes: 2_097_152)
)
guard let url = URL(string: "https://api.example.com/users") else {
  throw URLError(.badURL)
}
let request = HTTPRequest(
  method: .get,
  url: url,
  headers: ["Accept": "application/json"]
)
let response = try await client.execute(request)
guard let body = response.body else {
  throw HTTPError(category: .decoding("Expected a response body"), request: request)
}
let users = try codec.decode([User].self, from: body.rawValue)
```

`JSONCodec` applies configuration before it is shared and keeps its Foundation
encoder and decoder private. Custom coding closures must support concurrent
calls. Encoding and decoding preserve errors from the supplied Codable types.

To send JSON, encode with the same codec and pass the resulting `Data` to the
Foundation-valued `HTTPRequest` initializer together with a
`Content-Type: application/json` header. Construct query strings with
`URLComponents` and `URLQueryItem`.

---

## Configure transport defaults

`NetworkClient.Configuration.baseURL` resolves relative request URLs using
Foundation URL resolution. Its `defaultHeaders` supplies values that
request-specific headers override. A request-specific timeout overrides the
client default; otherwise the configured URLSession timeout applies when the
client has no override.

Inject a configured `URLSession` for session-level behavior such as connectivity
waiting and connection limits. `maximumResponseBytes` limits each response body,
including middleware-produced content; nil leaves that limit unrestricted.
A response limit does not constitute a general process-memory limit.

---

## Handle domain errors

`NetworkClient.execute(_:)` throws `HTTPError`. Its `category` distinguishes
transport failures, HTTP failures, encoding/decoding, timeout, cancellation,
configuration, and custom errors. HTTP 4xx and 5xx responses become failures
unless middleware recovers them. The error may retain its request, response,
and underlying failure, so avoid logging those objects without redaction.

The broader `HTTPClient` protocol allows arbitrary errors from custom clients.
Calls to `JSONCodec` can also throw Codable errors independently of transport.
Translate those failures at the application boundary that understands them.

Use <doc:Requests-and-Cancellation> for scoped ownership and
<doc:Middleware-Guide> for optional retry, caching, and telemetry.
