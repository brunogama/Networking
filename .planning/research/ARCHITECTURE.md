# Architecture Research: Observability Patterns for Swift Networking Libraries

## Executive Summary

This document analyzes architectural patterns for implementing observability (metrics, distributed tracing, structured logging) in Swift networking libraries. Based on analysis of the existing ModernNetworking codebase, established observability standards (OpenTelemetry, W3C Trace Context), and Swift 6 concurrency requirements, the following key architectural decisions are recommended:

1. **Metrics Architecture**: Actor-based collectors with protocol abstraction for pluggable backends
2. **Distributed Tracing**: W3C Trace Context propagation via HTTP headers with span lifecycle management
3. **Structured Logging**: OSLog integration with trace correlation via span IDs
4. **Integration Strategy**: Middleware-based hooks at request/response lifecycle boundaries
5. **Concurrency Model**: Actor isolation for mutable state, `@Sendable` protocols for all interfaces

The existing codebase already has significant observability infrastructure (`MetricsCollector`, `NetworkObservabilityMiddleware`, `DistributedTracing`) that provides a solid foundation for enhancement.

---

## Current State Analysis

### Existing Observability Components

The ModernNetworking library already contains observability infrastructure:

| Component | File | Purpose | Maturity |
|-----------|------|---------|----------|
| `MetricsCollector` | `MetricsCollector.swift` | Protocol + actor-based collectors | Production-ready |
| `NetworkObservabilityMiddleware` | `NetworkObservabilityMiddleware.swift` | Request lifecycle observability | Production-ready |
| `TracingMiddleware` | `DistributedTracing.swift` | W3C Trace Context injection | Production-ready |
| `TraceContext` | `DistributedTracing.swift` | W3C traceparent/tracestate | Production-ready |
| `TraceSpan` | `DistributedTracing.swift` | Span lifecycle management | Production-ready |
| `LoggingMiddleware` | `LoggingMiddleware.swift` | OSLog-based request logging | Production-ready |

### Key Design Patterns Already in Use

1. **Protocol Abstraction**: `MetricsCollector` protocol enables pluggable backends
2. **Actor Isolation**: `ComprehensiveMetricsCollector` and `NetworkObservabilityMiddleware` are actors
3. **Middleware Integration**: Observability hooks into `HTTPRequestMiddleware`, `HTTPResponseMiddleware`, `HTTPErrorMiddleware`
4. **Value Types**: All context types (`TraceContext`, `RequestContext`, `ResponseContext`) are `Sendable` structs

---

## Metrics Architecture

### Core Pattern: Counter/Gauge/Histogram Abstractions

The existing `MetricsCollector` protocol provides event-based recording. For comprehensive metrics, the industry standard (OpenTelemetry, Prometheus) defines three metric types:

```
+------------------+     +------------------+     +------------------+
|     Counter      |     |      Gauge       |     |    Histogram     |
+------------------+     +------------------+     +------------------+
| Monotonic sum    |     | Point-in-time    |     | Distribution     |
| (total requests) |     | (active conns)   |     | (latency p50/95) |
+------------------+     +------------------+     +------------------+
```

### Recommended Metric Types for Networking

| Metric Name | Type | Labels | Purpose |
|-------------|------|--------|---------|
| `http_requests_total` | Counter | method, status, endpoint | Request volume |
| `http_request_duration_seconds` | Histogram | method, endpoint | Latency distribution |
| `http_active_connections` | Gauge | host | Concurrency tracking |
| `http_request_size_bytes` | Histogram | method | Request payload sizes |
| `http_response_size_bytes` | Histogram | method, status | Response payload sizes |
| `http_errors_total` | Counter | method, error_type | Error classification |
| `http_retries_total` | Counter | method, endpoint | Retry frequency |
| `http_cache_hits_total` | Counter | endpoint | Cache effectiveness |
| `http_circuit_breaker_state` | Gauge | endpoint, state | Circuit breaker status |

### Swift Implementation Pattern

```
+------------------------+
|    MetricsCollector    |  <-- Protocol (Sendable)
|      (interface)       |
+------------------------+
           |
    +------+------+
    |             |
+--------+   +--------+
| Simple |   | Compr. |  <-- Concrete implementations (actors)
| Coll.  |   | Coll.  |
+--------+   +--------+
           |
    +------+------+
    |             |
+--------+   +--------+
| OSLog  |   | Custom |  <-- Exporters
| Export |   | Export |
+--------+   +--------+
```

### Existing Implementation Strengths

The current `ComprehensiveMetricsCollector` already implements:

- **Event Recording**: `recordEvent(_ event:)` with `ObservabilityEvent` enum
- **Performance Metrics**: `PerformanceMetrics` struct with p50/p95/p99 latencies
- **Time Windows**: `MetricsWindow` for aggregated time-series data
- **Alert Thresholds**: Configurable alerts for error rate, latency, throughput
- **Business Metrics**: DAU, sessions, conversion tracking

### Enhancement Opportunities

1. **Metric Type Abstraction**: Add explicit Counter/Gauge/Histogram types
2. **Label Support**: Add configurable labels to metrics
3. **Export Protocols**: Define protocol for external metric backends (Prometheus, StatsD)
4. **Cardinality Control**: Limit label combinations to prevent metric explosion

---

## Distributed Tracing Architecture

### W3C Trace Context Standard

The existing `TraceContext` struct implements W3C Trace Context correctly:

```
traceparent: 00-{trace-id}-{span-id}-{trace-flags}
             |       |         |          |
           ver   32-hex    16-hex      flags
                (128-bit) (64-bit)    (8-bit)
```

### Span Lifecycle Model

```
                    +----------------+
                    |  Root Span     |
                    | (HTTP Request) |
                    +-------+--------+
                            |
        +-------------------+-------------------+
        |                   |                   |
+-------+--------+  +-------+--------+  +-------+--------+
|   Child Span   |  |   Child Span   |  |   Child Span   |
| (DNS Lookup)   |  | (Connection)   |  | (Response)     |
+----------------+  +----------------+  +----------------+
```

### Trace Propagation Flow

```
+------------------+     +------------------+     +------------------+
|  Client App      |     |  Network Layer   |     |  Server          |
+------------------+     +------------------+     +------------------+
        |                        |                        |
        | 1. Create TraceContext |                        |
        +----------------------->|                        |
        |                        |                        |
        | 2. Inject traceparent  |                        |
        |    header              |                        |
        +----------------------->|                        |
        |                        | 3. Forward headers     |
        |                        +----------------------->|
        |                        |                        |
        |                        | 4. Propagate to        |
        |                        |    child spans         |
        |                        |<-----------------------+
        |                        |                        |
        | 5. Record span end     |                        |
        |<-----------------------+                        |
        |                        |                        |
```

### Existing Implementation Analysis

The current `TracingMiddleware` implements:

1. **Context Creation**: `TraceContext()` with random IDs
2. **Header Injection**: `traceparent` and `tracestate` headers
3. **Span Storage**: Actor-based `SpanStorage` for request correlation
4. **Span Attributes**: HTTP method, URL, host, status code

### Enhancement Opportunities

1. **Baggage Propagation**: Implement `tracestate` for vendor-specific context
2. **Sampling Strategies**: Head-based and tail-based sampling
3. **Span Events**: Record sub-operations within spans (DNS, TLS, body transfer)
4. **Export Integration**: Protocol for external trace collectors (Jaeger, Zipkin)

---

## Structured Logging Architecture

### OSLog Integration Pattern

The existing `LoggingMiddleware` uses OSLog correctly:

```swift
Logger(subsystem: "Networking", category: "HTTPClient")
```

### Log Correlation with Traces

For full observability, logs must correlate with traces:

```
+------------------+     +------------------+
|  Log Entry       |     |  Trace Span      |
+------------------+     +------------------+
| timestamp        |<--->| startTime        |
| trace_id         |<--->| traceId          |
| span_id          |<--->| spanId           |
| message          |     | name             |
| level            |     | status           |
+------------------+     +------------------+
```

### Recommended Log Structure

```json
{
  "timestamp": "2026-02-14T10:30:00Z",
  "level": "debug",
  "message": "Request completed",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "http.method": "GET",
  "http.url": "/users/123",
  "http.status_code": 200,
  "http.duration_ms": 142
}
```

### Swift 6 OSLog Pattern

```swift
actor TracingLogger {
    private let logger: Logger

    func log(_ message: String, context: TraceContext?) {
        if let ctx = context {
            logger.debug("\(message) [trace=\(ctx.traceId) span=\(ctx.spanId)]")
        } else {
            logger.debug("\(message)")
        }
    }
}
```

---

## Integration Points

### Middleware Chain Integration

The existing architecture provides clear integration points:

```
Request Flow:
+------------------+     +------------------+     +------------------+
| TracingMiddleware| --> | LoggingMiddleware| --> | AuthMiddleware   |
| (create span)    |     | (log request)    |     | (add headers)    |
+------------------+     +------------------+     +------------------+
         |                        |                        |
         v                        v                        v
+------------------+     +------------------+     +------------------+
| MetricsMiddleware| --> | NetworkClient    | --> | CachingMiddleware|
| (record metrics) |     | (execute)        |     | (cache check)    |
+------------------+     +------------------+     +------------------+

Response Flow:
+------------------+     +------------------+     +------------------+
| TracingMiddleware| <-- | LoggingMiddleware| <-- | ResponseValidate |
| (end span)       |     | (log response)   |     | (validate)       |
+------------------+     +------------------+     +------------------+
```

### Request Lifecycle Hooks

| Hook | Type | Observability Action |
|------|------|---------------------|
| Pre-request | `HTTPRequestMiddleware` | Create span, start timer |
| Post-response | `HTTPResponseMiddleware` | End span, record latency |
| Error handling | `HTTPErrorMiddleware` | Record error, set span status |
| Cache hit | `CachingInterceptor` | Record cache metric |
| Retry attempt | `RetryInterceptor` | Record retry count |
| Rate limit | `RateLimitInterceptor` | Record limit event |

### Context Propagation via InterceptorContext

The existing `InterceptorContext` can carry trace context:

```swift
// Current metadata support
public let metadata: [String: AnySendable]

// Usage for trace context
let context = InterceptorContext(
    path: "/users/123",
    method: .get,
    metadata: [
        "trace_id": .string(traceContext.traceId),
        "span_id": .string(traceContext.spanId)
    ]
)
```

---

## Data Flow

### Trace Context Propagation Through Interceptors

```
+----------------------------------------------------------+
|                      NetworkClient                        |
+----------------------------------------------------------+
        |
        v
+----------------------------------------------------------+
|  TracingMiddleware (Request Phase)                        |
|  1. Create TraceContext with random IDs                   |
|  2. Create TraceSpan for this request                     |
|  3. Inject traceparent header                             |
|  4. Store span in SpanStorage (actor)                     |
+----------------------------------------------------------+
        |
        v (request with traceparent header)
+----------------------------------------------------------+
|  LoggingMiddleware                                        |
|  - Log request with trace_id from header                  |
+----------------------------------------------------------+
        |
        v
+----------------------------------------------------------+
|  NetworkObservabilityMiddleware                           |
|  1. Extract trace context from request headers            |
|  2. Create RequestContext with trace IDs                  |
|  3. Record requestStarted event                           |
+----------------------------------------------------------+
        |
        v
+----------------------------------------------------------+
|  URLSession.data(for:)                                    |
|  - Network request with traceparent propagated            |
+----------------------------------------------------------+
        |
        v
+----------------------------------------------------------+
|  NetworkObservabilityMiddleware (Response Phase)          |
|  1. Calculate duration                                    |
|  2. Record requestCompleted event                         |
|  3. Update performance metrics                            |
+----------------------------------------------------------+
        |
        v
+----------------------------------------------------------+
|  TracingMiddleware (Response Phase)                       |
|  1. Retrieve span from SpanStorage                        |
|  2. Set status attribute                                  |
|  3. End span                                              |
|  4. Export span (if exporter configured)                  |
+----------------------------------------------------------+
        |
        v
+----------------------------------------------------------+
|  MetricsCollector                                         |
|  - Aggregate metrics from events                          |
|  - Calculate p50/p95/p99 latencies                        |
|  - Check alert thresholds                                 |
+----------------------------------------------------------+
```

### Error Path Flow

```
+----------------------------------------------------------+
|  Error occurs during request                              |
+----------------------------------------------------------+
        |
        v
+----------------------------------------------------------+
|  NetworkObservabilityMiddleware.handleError               |
|  1. Create ErrorContext from HTTPError                    |
|  2. Record requestFailed event                            |
|  3. Update error counts                                   |
+----------------------------------------------------------+
        |
        v
+----------------------------------------------------------+
|  TracingMiddleware (Error handling)                       |
|  1. Retrieve span                                         |
|  2. Set error status                                      |
|  3. Add error attributes                                  |
|  4. End span                                              |
+----------------------------------------------------------+
        |
        v
+----------------------------------------------------------+
|  RetryInterceptor (if configured)                         |
|  1. Check if retryable                                    |
|  2. Record retry event                                    |
|  3. Create child span for retry                           |
+----------------------------------------------------------+
```

---

## Build Order

### Component Dependencies

```
Level 0 (Foundation):
+------------------+     +------------------+
|  TraceContext    |     |  SpanStatus      |
|  (value type)    |     |  (enum)          |
+------------------+     +------------------+

Level 1 (Core Types):
+------------------+     +------------------+
|  TraceSpan       |     |  MetricsCollector|
|  (reference type)|     |  (protocol)      |
+------------------+     +------------------+

Level 2 (Exporters):
+------------------+     +------------------+
|  TraceExporter   |     |  ConsoleExporter |
|  (protocol)      |     |  (concrete)      |
+------------------+     +------------------+

Level 3 (Contexts):
+------------------+     +------------------+
|  RequestContext  |     |  ResponseContext |
|  (value type)    |     |  (value type)    |
+------------------+     +------------------+

Level 4 (Collectors):
+------------------+     +------------------+
|  SimpleCollector |     |  Comprehensive   |
|  (actor)         |     |  Collector       |
+------------------+     +------------------+

Level 5 (Middleware):
+------------------+     +------------------+
|  TracingMW       |     |  ObservabilityMW |
|  (implements all)|     |  (implements all)|
+------------------+     +------------------+
```

### Build Order for New Features

When adding new observability features, follow this order:

1. **Value Types First**: `TraceContext`, `SpanEvent`, `MetricLabel`
2. **Protocols Second**: `MetricsCollector`, `TraceExporter`, `LogFormatter`
3. **Actors Third**: `ComprehensiveMetricsCollector`, `SpanStorage`
4. **Middleware Last**: `TracingMiddleware`, `NetworkObservabilityMiddleware`

### Incremental Implementation Strategy

| Phase | Components | Depends On |
|-------|------------|------------|
| 1 | Metric type abstractions (Counter/Gauge/Histogram) | None |
| 2 | Label support for metrics | Phase 1 |
| 3 | Baggage propagation (tracestate) | Existing TraceContext |
| 4 | Span events (DNS, TLS, body) | Existing TraceSpan |
| 5 | Log correlation with traces | Phase 3-4 |
| 6 | External exporters (Prometheus, Jaeger) | Phase 1-5 |

---

## Swift 6 Concurrency Considerations

### Actor Isolation Requirements

All mutable state must be protected by actors:

```swift
// Correct: Actor-protected mutable state
actor MetricsStorage {
    private var counters: [String: Int64] = [:]

    func increment(_ name: String, by value: Int64) {
        counters[name, default: 0] += value
    }
}

// Incorrect: Shared mutable state
class MetricsStorage {  // Not Sendable
    var counters: [String: Int64] = [:]  // Data race!
}
```

### Sendable Protocol Compliance

All public types must be `Sendable`:

| Type | Sendable Strategy |
|------|-------------------|
| `TraceContext` | `struct` (value type) |
| `TraceSpan` | `@unchecked Sendable` with `NSLock` |
| `MetricsCollector` | Protocol requiring `Sendable` |
| `ComprehensiveMetricsCollector` | `actor` |
| `TracingMiddleware` | `@unchecked Sendable` with actor storage |

### Async/Await Pattern

All observability operations should be async:

```swift
// Correct: Async metrics recording
public protocol MetricsCollector: Sendable {
    func recordEvent(_ event: ObservabilityEvent) async
    func recordPerformanceMetrics(_ metrics: PerformanceMetrics) async
}

// Correct: Async span export
public protocol TraceExporter: Sendable {
    func export(_ span: TraceSpan) async throws
    func flush() async throws
}
```

### Task Group Usage for Parallel Export

```swift
// Export to multiple backends concurrently
await withTaskGroup(of: Void.self) { group in
    for collector in collectors {
        group.addTask {
            await collector.recordEvent(event)
        }
    }
}
```

---

## Recommendations Summary

### Immediate Enhancements (Low Risk)

1. **Add metric labels**: Extend existing metrics with configurable labels
2. **Implement tracestate**: Add vendor-specific baggage propagation
3. **Log correlation**: Include trace_id and span_id in all log entries
4. **Span events**: Add events for DNS, TLS, body transfer phases

### Medium-Term Enhancements (Medium Risk)

1. **Metric type abstraction**: Define Counter/Gauge/Histogram protocols
2. **Sampling strategies**: Head-based and tail-based sampling support
3. **Export protocols**: Define interfaces for Prometheus, StatsD, Jaeger
4. **Cardinality limits**: Prevent metric explosion with label validation

### Long-Term Enhancements (Higher Risk)

1. **OpenTelemetry compatibility**: Align with OpenTelemetry semantic conventions
2. **Auto-instrumentation**: Generate observability code via macros
3. **Async profiling**: Integrate with Instruments for trace visualization
4. **Distributed sampling**: Coordinate sampling decisions across services

---

## References

- W3C Trace Context: https://www.w3.org/TR/trace-context/
- OpenTelemetry Specification: https://opentelemetry.io/docs/specs/otel/
- Apple OSLog Documentation: https://developer.apple.com/documentation/os/logging
- Swift Concurrency: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html
- Existing Codebase: `Sources/Networking/MetricsCollector.swift`, `DistributedTracing.swift`, `NetworkObservabilityMiddleware.swift`
