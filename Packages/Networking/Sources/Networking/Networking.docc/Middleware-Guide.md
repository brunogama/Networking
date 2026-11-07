# Middleware Guide

Compose the optional behavior a client needs through explicit ordered stages.

---

## Pipeline ownership

`HTTPMiddleware` contains request, response, and error arrays. Request stages run
in registration order before transport. Response stages run in order after a
network response or recovery. Error stages receive failures in order until one
recovers or the final error is thrown.

| Protocol | Operation |
| --- | --- |
| `HTTPRequestMiddleware` | `modifyRequest(_:)` |
| `HTTPResponseMiddleware` | `processResponse(_:for:)` |
| `HTTPErrorMiddleware` | `handleError(_:for:)` |

Use an actor or another explicit synchronization owner for mutable middleware
state. Treat every suspension as an opportunity for another call to change that
state. A middleware that reconstructs a request must preserve its logical `id`.

Retry, authentication recovery, and prefetch need an injected transport client.
Give them a separate client whose pipeline does not recurse into the same
middleware. Register each object in every stage it implements and needs.

---

## Retry

```swift
let transport = NetworkClient()
let retry = RetryMiddleware(
  configuration: try .init(maxAttempts: 2, initialDelay: .seconds(1)),
  client: transport
)
let client = NetworkClient(middleware: HTTPMiddleware(error: [retry]))
```

`maxAttempts` counts additional attempts after the original failure. Delays grow
exponentially to the configured cap. The default predicate retries selected
transient failures of idempotent methods; callers must explicitly opt other
operations into replay. Cancellation interrupts retry delays and prevents the
next request. Application-specific recovery decisions belong to the caller.

---

## Optional caching

```swift
let transport = NetworkClient()
let cache = CachingMiddleware(
  configuration: .init(defaultTTL: 300),
  storage: MemoryCacheStorage(maxSize: 100),
  client: transport
)
let client = NetworkClient(
  middleware: HTTPMiddleware(request: [cache], response: [cache])
)
```

The default policy stores successful GET responses unless the server specifies
`no-store` or `no-cache`. Stale entries can supply ETag or Last-Modified
validators; a 304 response is combined with retained content. Cache hits carry
the current request identity. This optional middleware is not a claim of complete
HTTP shared-cache conformance.

Custom logical keys do not disable request-header partitioning. Cookie and
authorization inputs remain isolated; `Vary: *` responses are not stored.
Use `configuration.metadataExtractor` to supply explicit `CacheMetadata` tags,
keys, or freshness overrides. Tags participate in invalidation and survive disk
persistence. Cache policy still determines whether sensitive responses should be
stored at all; response caching is not credential storage.

Choose `MemoryCacheStorage`, `AdvancedMemoryCacheStorage`, `DiskCacheStorage`,
or `HybridCacheStorage` according to retention requirements. One disk-storage
owner should manage a directory. Disk storage reserves `cache_metadata.json`
and regular SHA-256-named `.cache` files, reuses its own codec, and writes metadata
once per batch deletion. It preserves unrelated files and directories.

`clearCache()` and targeted invalidation advance the middleware's generation
before awaiting storage. Older prefetch work cannot repopulate it afterward.
Writes and invalidation are ordered, and cancelled prefetch results are not
retained. This generation belongs to one middleware instance; it does not
retrospectively identify an ordinary request whose `processResponse` starts only
after invalidation. Coordinate account changes and outstanding requests at the
application boundary.

---

## Distributed tracing and OTLP

Add the `NetworkingObservabilityOTLP` product for collector export:

```swift
import Foundation
import Networking
import NetworkingObservabilityOTLP

guard let endpoint = URL(string: "https://collector.example") else {
  throw URLError(.badURL)
}
let exporter = try OTLPTraceExporter(
  configuration: OTLPConfiguration(
    endpoint: HTTPRequestURL(endpoint),
    resource: OTLPResource(serviceName: "ExampleApp")
  )
)
let tracing = TracingMiddleware(exporter: exporter)
let client = NetworkClient(
  middleware: HTTPMiddleware(request: [tracing], response: [tracing], error: [tracing])
)
```

Register tracing in all three stages so successful and failed requests complete
their spans. When combining error stages, place tracing before recovery stages
that may return early. Tracing preserves request identity and propagates W3C
trace context. Default span attributes contain method and host, not credentials,
URL queries, or bodies.

Exports use awaited HTTP protobuf requests to the collector's `/v1/traces` and
`/v1/metrics` paths. Direct exporter calls report transport, cancellation,
rejection, and encoding errors. Middleware export failures leave the HTTP result
unchanged. There is no background export worker or flush lifecycle.

`MetricsCollector.record(_:)` accepts a validated `HTTPRequestMetrics` duration,
completion time, and outcome supplied by the caller. `SimpleMetricsCollector`
retains a bounded sample list. `OTLPMetricsCollector` exports cumulative duration
histograms with actual observation counts and sums. Failed delivery remains in
its totals for the next sample; it does not automatically retry. These collectors
do not install request instrumentation by themselves.

See <doc:Security-Features> for credential providers and TLS policies, and
<doc:Requests-and-Cancellation> for native diagnostics.
