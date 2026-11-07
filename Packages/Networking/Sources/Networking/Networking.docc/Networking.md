# ``Networking``

HTTP requests, explicit middleware, and scoped cancellation for Swift 6 applications.

---

## Overview

Create `HTTPRequest` values and execute them through `NetworkClient`. Configure
transport defaults with `NetworkClient.Configuration`, and install optional
behavior through `HTTPMiddleware` arrays. Stateful services own their mutable
state; request tickets give one scope ownership of a response and cancellation.

The package targets iOS 16, macOS 13, tvOS 16, and watchOS 9 or later and uses
Swift 6 language mode. The native SwiftUI traffic inspector supports iOS and macOS.

---

## Products

| Product | Responsibility |
| --- | --- |
| `Networking` | Re-exports Core, Runtime, Observability, and SSE for a single application import |
| `NetworkingCore` | HTTP values, domain errors, client protocols, and `JSONCodec` |
| `NetworkingRuntime` | URLSession execution, tickets, middleware, caching, security, and file transfers |
| `NetworkingObservability` | Native inspector, trace contracts, tracing middleware, and completed-request metrics |
| `NetworkingObservabilityOTLP` | Optional awaited OTLP HTTP protobuf export |
| `NetworkingSSE` | Server-sent event parsing and streaming transport |
| `NetworkingTesting` | Explicit test dependency with mocks, fakes, and URLProtocol stubs |

The separate `Packages/NetworkingMacros` package generates clients that receive
an injected HTTP client and reusable codec. It is not a dependency of the
`Networking` umbrella product.

---

## Topics

### Using the client

- <doc:Getting-Started>
- <doc:Requests-and-Cancellation>

### Optional behavior

- <doc:Middleware-Guide>
- <doc:Security-Features>
