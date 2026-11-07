# Requests and Cancellation

Own request work explicitly and inspect transport attempts without retaining secrets by default.

---

## Scoped request tickets

```swift
import Networking

let response = try await client.withRequest(request) { ticket in
  try await ticket.response()
}
```

`withRequest` starts work in a structured task group and supplies a
`RequestTicket<RequestRunning>` to the closure. The ticket is noncopyable:
`response()` and `cancel()` consume it. Leaving the closure cancels unfinished
work and joins child tasks before the scope returns.

Retain `ticket.cancellation` when another task or a UI action needs to cancel
while `response()` is suspended. This shareable handle returns true only when
cancellation wins the terminal-result race. Repeated cancellation is inert;
cancelling one request does not cancel other operations on the client.

The ticket's phase represents authority to await or cancel, not a promise that
the remote connection is still open. Completion is checked at runtime.
`RequestTicketID`, `HTTPRequestID`, and `HTTPTraceID` identify different domains.

`response()` throws `HTTPError`, including `.cancelled`. The enclosing closure
may throw its own errors. Cancellation is cooperative: a custom `HTTPClient`
that ignores it can delay scope exit.

---

## Batches and cache warming

`executeBatch(_:configuration:)` accepts an array of request values. Its default
configuration allows eight concurrent child tasks. Results identify their input
index and are returned in input order. Cancellation stops scheduling and cancels
active work; unstarted requests are omitted from the result array.

`CachingMiddleware.warmCache(requests:concurrency:)` takes explicit requests and
uses a bounded task group. `prefetchSingle(request:)` runs in the caller's task.
Concurrent prefetch callers remain independent; there is no shared HTTP memoizer.
See <doc:Middleware-Guide> for cache storage and invalidation boundaries.

---

## Native diagnostics

```swift
let diagnostics = NetworkDiagnostics(capacity: 100, logs: false)
let client = NetworkClient(
  middleware: HTTPMiddleware(),
  configuration: .init(diagnostics: diagnostics)
)
```

Present `NetworkInspector(diagnostics: diagnostics)` from a SwiftUI view on iOS
or macOS. `diagnostics.traces` provides snapshots, `changes()` provides bounded
change notifications, and `export()` encodes retained traces as JSON.

Diagnostics records URLSession attempts, including available redirect,
connection-reuse, DNS, TCP, TLS, and first-byte measurements. Native uploads,
downloads, and SSE attempts can use the same recorder. Cache hits do not create
a transport attempt. Logging is enabled by default under OSLog subsystem
`Networking`, category `HTTP`; `logs: false` disables it independently of storage.

Authorization and cookie headers are redacted by default. URL credentials,
fragments, and query values are removed or redacted. Body capture is disabled;
`HTTPTracePrivacy.capturesBodies` explicitly enables bounded prefixes. Downloaded
file contents and SSE event bodies are not captured. URL path components and
arbitrary body fields are not automatically scrubbed.

---

## Files and event streams

`FileTransferOperations(httpClient:)` uses native URLSession upload and download
operations when its client supports them. A custom client or a client with error
middleware uses buffered execution instead. Native transfers report transport
progress; buffered operations report terminal completion rather than simulated
intermediate percentages. Cancel the owning task to cancel native foreground
work. Background resume requires supported configuration and valid resume data;
it is not a general pause/resume control for every request.

`SSEClient(session:requestMiddlewares:diagnostics:)` opens an
`AsyncThrowingStream` through `connect(_:configuration:)`. Retain and cancel the
owning consumer task as appropriate. Stream termination cancels its connection
worker; merely leaving a loop while retaining the stream is not a substitute for
ending its ownership. Buffer overflow is reported rather than silently losing
an event. SSE transport and request tickets have distinct lifetime contracts.
