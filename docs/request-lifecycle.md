# Request lifecycle and diagnostics

A request ticket gives one operation ownership of its result and cancellation.
If a screen disappears while a request is running, cancellation must stop the
wait and propagate to the network task. The request's work must also finish
before its owning scope exits.

## Scoped tickets

```swift
import Networking

let response = try await client.withRequest(request) { ticket in
    try await ticket.response()
}
```

`withRequest` creates structured child tasks. It supplies a
`RequestTicket<RequestRunning>` to the closure and waits for cleanup before
returning. Returning or throwing from the closure cancels unfinished work.
Cancellation remains cooperative: a custom `HTTPClient` that ignores task
cancellation can delay scope exit.

The ticket is `~Copyable`. Both `response()` and `cancel()` consume it, preventing
duplicate result consumption. `ticket.cancellation` is a shareable, thread-safe
handle for an external cancel action while `response()` is suspended. Its
`cancel()` method returns true only if cancellation wins the terminal-result
race; subsequent calls return false. Cancelling one operation does not cancel
other requests on the same client.

The phantom phase describes authority to perform an operation. It does not
claim the remote connection is still open: completion and cancellation races
are checked under a lock. `RequestTicketID`, `HTTPRequestID`, and `HTTPTraceID`
are distinct domains and cannot be interchanged.

Authentication refresh uses the complementary pattern for shared state: its
actor owns an explicit `idle` or `refreshing` flight. Concurrent unauthorized
requests join the same flight. Individual request cancellation never cancels
that shared refresh; the owning middleware cancels it only during teardown.

`NetworkClient.execute(_:)` and `RequestTicket.response()` throw `HTTPError`.
Arbitrary middleware and custom-client failures retain their underlying error
inside a domain-specific `HTTPError`. The `HTTPClient` protocol and
`withRequest` closure still permit arbitrary caller errors.

---

## Diagnostics

```swift
let diagnostics = NetworkDiagnostics()
let client = NetworkClient(
    middleware: HTTPMiddleware(),
    configuration: .init(diagnostics: diagnostics)
)
```

Use the same recorder with `SSEClient(session:diagnostics:)` for event streams.
`NetworkInspector(diagnostics:)` provides a native SwiftUI inspector on iOS and
macOS. `diagnostics.traces` returns snapshots; `diagnostics.changes()` provides
bounded change notifications; `diagnostics.export()` produces JSON.

Recording is opt-in per client. An enabled recorder retains at most 100 attempts
by default and emits OSLog events in subsystem `Networking`, category `HTTP`.
Set `logs: false` to disable unified logging. Native data requests, uploads,
downloads, and SSE attempts are recorded. Cache hits perform no network attempt
and therefore create no transport trace. Metrics include redirect transactions,
connection reuse, protocol, and available DNS, TCP, TLS, and first-byte timings.

Authorization and cookie headers are redacted by default. URL credentials,
fragments, and query values are removed or redacted. Body capture is disabled;
enable `HTTPTracePrivacy.capturesBodies` explicitly to retain bounded body
prefixes. File download contents and SSE event bodies are not captured.
Redaction does not inspect arbitrary URL path components or body fields.

---

## Smaller configuration and domain types

`HTTPMiddleware` groups request, response, and error stages. Transport defaults
belong to `NetworkClient.Configuration`; move the former `defaultTimeout`
initializer argument to `.init(timeout:)`. Common convenience initializers
remain available.

`TaggedValue<Domain, RawValue>` implements shared scalar behavior once, with
conditional conformances. `Identifier<Domain, RawValue>` names the identity use
case. Existing boundary aliases use this implementation and retain single-value
Codable representations. A tagged value distinguishes domains; domain-specific
validation still belongs at the input boundary.

---

## Optional caching and memoization

The existing caching middleware remains opt-in. Request tickets do not add a
second cache or combine independent requests into one shared transport task.

The proposed memoizer's generation token is useful: an invalidated flight cannot
publish over its replacement. Adopting it for HTTP requires explicit freshness,
capacity, request identity, authorization partitioning, and invalidation rules.
A cancelled caller should stop its own wait; cancellation of shared work needs
a separate policy for the remaining callers.

The supplied detached-task implementation is not installed. A future shared
flight implementation needs an explicit owner and cancellation contract before
adding property-wrapper syntax. The current ticket implementation uses task
groups and creates no detached tasks.
