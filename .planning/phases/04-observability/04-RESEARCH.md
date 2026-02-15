# Phase 4: Observability - Research Document

**Phase Goal**: Enable production monitoring with distributed tracing and metrics

**Research Date**: 2026-02-15

**Status**: Phase 4 research complete - ready for planning

---

## Executive Summary

Phase 4 implements production-grade observability through distributed tracing, metrics collection, and structured logging. The codebase **already has substantial observability infrastructure** (W3C Trace Context, span management, metrics collection, structured logging), requiring primarily **integration work** rather than ground-up implementation.

**Key Finding**: The project has:
- ✅ W3C Trace Context implementation (`DistributedTracing.swift`)
- ✅ Comprehensive metrics collection (`MetricsCollector.swift`)
- ✅ Network observability middleware (`NetworkObservabilityMiddleware.swift`)
- ✅ Structured logging (`LoggingMiddleware.swift`)
- ⚠️ **Missing**: swift-otel integration (OBS-03 requirement)

**Recommended Approach**: Extend existing infrastructure with swift-otel backend integration, not replace.

---

## Requirements Analysis

### Phase 4 Requirements (from REQUIREMENTS.md)

| Req ID | Requirement | Current Status | Gap Analysis |
|--------|-------------|----------------|--------------|
| **OBS-01** | Distributed tracing span creation | ✅ **COMPLETE** | `TraceSpan` actor in `DistributedTracing.swift` |
| **OBS-02** | Trace context propagation in headers | ✅ **COMPLETE** | `TracingMiddleware` injects `traceparent`/`tracestate` |
| **OBS-03** | swift-otel integration | ❌ **MISSING** | No OpenTelemetry backend exporters |
| **OBS-04** | Request timing metrics | ✅ **COMPLETE** | `NetworkObservabilityMiddleware` tracks duration/percentiles |
| **OBS-05** | Success/failure rate tracking | ✅ **COMPLETE** | `PerformanceMetrics` calculates error rates |
| **OBS-06** | Structured logging | ✅ **COMPLETE** | `LoggingMiddleware` uses OSLog |
| **OBS-07** | Custom metrics collection | ✅ **COMPLETE** | `MetricsCollector` protocol + implementations |

**Completion**: 6/7 requirements (86%) already implemented

**Primary Gap**: OBS-03 (swift-otel integration) for exporting to OpenTelemetry backends

---

## Existing Infrastructure Deep Dive

### 1. W3C Trace Context Implementation (`DistributedTracing.swift`)

**Location**: `/Packages/Networking/Sources/Networking/DistributedTracing.swift` (380 lines)

**Current Capabilities**:
- ✅ W3C Trace Context spec-compliant `TraceContext` struct
- ✅ `traceparent` header generation (format: `00-{trace-id}-{span-id}-{flags}`)
- ✅ `tracestate` header support (vendor-specific state)
- ✅ Trace ID generation (16-byte/32-hex-char globally unique)
- ✅ Span ID generation (8-byte/16-hex-char)
- ✅ Sampled flag support (bit 0 of traceFlags)
- ✅ `TraceSpan` actor for thread-safe span management
- ✅ Span attributes, events, status tracking
- ✅ `TracingMiddleware` for automatic header injection
- ✅ `TraceExporter` protocol for backend integration
- ✅ `ConsoleTraceExporter` for debugging

**Architecture**:
```swift
// W3C Trace Context
public struct TraceContext: Sendable, Equatable {
  let traceId: String      // 32-hex-char globally unique
  let spanId: String       // 16-hex-char span identifier
  let parentSpanId: String?
  let traceFlags: UInt8    // Bit 0 = sampled
  let traceState: [String: String]

  var traceparent: String  // "00-{trace}-{span}-{flags}"
  var tracestateHeader: String?
}

// Span management (actor-isolated for safety)
public actor TraceSpan {
  let name: String
  let context: TraceContext
  let startTime: Date
  var endTime: Date?
  var status: SpanStatus
  var attributes: [String: String]
  var events: [SpanEvent]
}

// Middleware integration
public final class TracingMiddleware: HTTPRequestMiddleware,
                                      HTTPResponseMiddleware {
  func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    let context = TraceContext()
    let span = TraceSpan(name: "\(method) \(path)", context: context)
    // Inject traceparent/tracestate headers
    // Store span for response processing
  }
}
```

**Strengths**:
- Full W3C Trace Context spec compliance
- Actor-isolated span storage (thread-safe)
- Automatic header injection via middleware
- Extensible via `TraceExporter` protocol

**Gaps**:
- Only `ConsoleTraceExporter` implemented (debug-only)
- No OpenTelemetry OTLP exporter
- No batching/buffering for production workloads
- No sampling strategies (currently 100% or 0%)

---

### 2. Metrics Collection System (`MetricsCollector.swift`)

**Location**: `/Packages/Networking/Sources/Networking/MetricsCollector.swift` (915 lines)

**Current Capabilities**:
- ✅ `MetricsCollector` protocol for pluggable backends
- ✅ `ComprehensiveMetricsCollector` actor (production-ready)
- ✅ `SimpleMetricsCollector` actor (lightweight)
- ✅ `ConsoleMetricsCollector` struct (debugging)
- ✅ `ObservabilityCompositeMetricsCollector` (multi-backend)
- ✅ Performance metrics (throughput, latency percentiles, error rates)
- ✅ Business metrics (DAU, sessions, retention)
- ✅ Alert system with configurable thresholds
- ✅ Time-windowed metrics aggregation (5-min windows)
- ✅ Optional persistence to disk (JSON)
- ✅ Real-time metric calculation

**Performance Metrics Tracked**:
```swift
public struct PerformanceMetrics: Sendable {
  let timestamp: Date
  let totalRequests: Int
  let successfulRequests: Int
  let failedRequests: Int
  let averageResponseTime: TimeInterval
  let p50ResponseTime: TimeInterval  // Median
  let p95ResponseTime: TimeInterval  // 95th percentile
  let p99ResponseTime: TimeInterval  // 99th percentile
  let errorRate: Double
  let throughput: Double             // req/sec
  let activeConnections: Int
  let cacheHitRate: Double
  let retryRate: Double
  let topErrors: [String: Int]
  let topSlowEndpoints: [(String, TimeInterval)]
  let networkHealth: NetworkHealth   // A/B/C/D/F grading
}
```

**Alert System**:
- Error rate threshold alerts (default: >5%)
- Response time threshold alerts (default: >2s)
- Low throughput alerts (default: <0.1 req/sec)
- High connection count alerts (default: >1000)
- Configurable via `AlertThresholds` struct

**Strengths**:
- Actor-isolated for thread safety
- Multiple implementation strategies (comprehensive/simple/console)
- Composite collector for multi-backend export
- Business metrics tracking (DAU, sessions, retention)
- Alert system with severity levels

**Gaps**:
- No OpenTelemetry Metrics exporter
- No StatsD/Prometheus format export
- Alert handlers not extensible (only OSLog)
- Persistence is JSON-only (no efficient time-series format)

---

### 3. Network Observability Middleware (`NetworkObservabilityMiddleware.swift`)

**Location**: `/Packages/Networking/Sources/Networking/NetworkObservabilityMiddleware.swift` (820 lines)

**Current Capabilities**:
- ✅ Request/response/error event tracking
- ✅ Real-time performance metric calculation
- ✅ Trace context management (active spans)
- ✅ Custom tags and metadata extraction
- ✅ Header redaction for security (Authorization, Cookie, etc.)
- ✅ Sampling support (configurable 0.0-1.0)
- ✅ Network health grading (A/B/C/D/F based on latency/reliability)
- ✅ Endpoint-level performance tracking
- ✅ Integration with `MetricsCollector` protocol

**Observability Events**:
```swift
public enum ObservabilityEvent: Sendable {
  case requestStarted(RequestContext)
  case requestCompleted(RequestContext, ResponseContext)
  case requestFailed(RequestContext, ErrorContext)
  case requestRetried(RequestContext, retryAttempt: Int)
  case circuitBreakerTripped(endpoint: String, reason: String)
  case cacheHit(RequestContext, cacheKey: String)
  case cacheMiss(RequestContext, cacheKey: String)
  case rateLimitHit(RequestContext, limit: Int, windowSeconds: TimeInterval)
  case authenticationsRefreshed(RequestContext)
  case middlewareError(RequestContext, middlewareName: String, error: String)
}
```

**Context Extraction**:
- HTTP method, URL, host, path
- Request/response headers (with redaction)
- Body sizes, content types
- User-Agent, correlation IDs
- Session/User/Device IDs (from headers)
- App version, platform, network type
- Custom tags via `customTagExtractor`

**Strengths**:
- Comprehensive context capture (12+ fields per request)
- Actor-isolated state management
- Sampling support (production-friendly)
- Security-first (header redaction)
- Network health grading (actionable metrics)

**Gaps**:
- No OpenTelemetry semantic conventions mapping
- Events not exportable to OTLP format
- No resource attributes (service name, version, environment)
- No span links or parent-child relationships beyond single request

---

### 4. Structured Logging (`LoggingMiddleware.swift`)

**Location**: `/Packages/Networking/Sources/Networking/LoggingMiddleware.swift` (134 lines)

**Current Capabilities**:
- ✅ OSLog integration (Apple's structured logging)
- ✅ Configurable subsystem/category
- ✅ Log level control (debug, info, error, fault)
- ✅ Request/response header logging (optional)
- ✅ Request/response body logging (optional, with size limit)
- ✅ Error logging with underlying error details

**Configuration**:
```swift
public struct Configuration: Sendable {
  let subsystem: String           // Default: "Networking"
  let category: String            // Default: "HTTPClient"
  let logLevel: OSLogType         // Default: .debug
  let logHeaders: Bool            // Default: true
  let logBody: Bool               // Default: false
  let maxBodyLength: Int          // Default: 1024
}
```

**Strengths**:
- Native OSLog integration (efficient, privacy-aware)
- Configurable verbosity (production vs development)
- Body logging size limits (prevents log explosion)

**Gaps**:
- No structured fields (logs are strings, not JSON)
- No correlation with trace IDs (not linked to spans)
- No custom log exporters (OSLog only)
- No log levels beyond OSLog's built-in types

---

## OpenTelemetry Swift Ecosystem

### Available Packages

#### 1. **opentelemetry-swift** (Official CNCF Project)

**Repository**: https://github.com/open-telemetry/opentelemetry-swift
**Package**: `https://github.com/open-telemetry/opentelemetry-swift.git`
**Version**: 2.3.0 (stable, released Jan 2026)
**License**: Apache 2.0
**Swift Version**: 5.10+ (Swift 6 compatible)
**Platforms**: iOS 16+, macOS 13+, tvOS 16+, watchOS 9+
**Data Race Safety**: ✅ Zero data race safety errors (SPI verified)
**Stars**: 326, Contributors: 81, Commits: 1,109

**Key Products**:
```swift
.package(url: "https://github.com/open-telemetry/opentelemetry-swift.git", from: "2.3.0")

dependencies: [
  .product(name: "OpenTelemetryApi", package: "opentelemetry-swift"),
  .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift"),
  .product(name: "OpenTelemetryProtocolExporter", package: "opentelemetry-swift"),
  .product(name: "ResourceExtension", package: "opentelemetry-swift"),
  .product(name: "StdoutExporter", package: "opentelemetry-swift"),
  .product(name: "ZipkinExporter", package: "opentelemetry-swift"),
  .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
]
```

**Maturity**:
- **Traces**: Stable
- **Metrics**: Development
- **Logs**: Development

**URLSession Instrumentation**: Built-in automatic instrumentation for URLSession (conflict risk with our middleware)

---

#### 2. **swift-otel** (Server-Side Swift Focus)

**Repository**: https://github.com/swift-otel/swift-otel
**Package**: `https://github.com/swift-otel/swift-otel.git`
**Version**: 1.0.0 (stable, released Sep 2025)
**License**: Apache 2.0
**Swift Version**: 6.0+ (designed for Swift 6)
**Platforms**: macOS, Linux (server-focused)
**Stars**: 185, Contributors: Multiple, Commits: 378

**Key Products**:
```swift
.package(url: "https://github.com/swift-otel/swift-otel.git", from: "1.0.0")

dependencies: [
  .product(name: "OTel", package: "swift-otel"),
  .product(name: "OTLPGRPC", package: "swift-otel"),
  .product(name: "OTLPHTTPExporter", package: "swift-otel"),
]
```

**Focus**: Integration with Swift Log, Swift Metrics, Swift Distributed Tracing

**Differences from opentelemetry-swift**:
- Server-side Swift oriented (uses Swift Log/Metrics APIs)
- OTLP-first (gRPC and HTTP exporters)
- Designed for Swift Concurrency (async/await native)
- No automatic instrumentation libraries
- Smaller footprint, focused on backend integration

---

### Comparison: opentelemetry-swift vs swift-otel

| Feature | opentelemetry-swift | swift-otel |
|---------|---------------------|------------|
| **Primary Use Case** | iOS/macOS apps | Server-side Swift |
| **Automatic Instrumentation** | ✅ URLSession, MetricKit | ❌ Manual only |
| **OTLP Exporter** | ✅ gRPC + HTTP | ✅ gRPC + HTTP |
| **Swift Concurrency** | ✅ Compatible | ✅ Native design |
| **Metrics API** | OpenTelemetry Metrics | Swift Metrics |
| **Logging API** | Custom | Swift Log |
| **Tracing API** | OpenTelemetry API | Swift Distributed Tracing |
| **Platforms** | iOS, macOS, tvOS, watchOS | macOS, Linux |
| **Maturity** | Traces: Stable<br>Metrics: Dev<br>Logs: Dev | 1.0.0 stable |
| **Data Race Safety** | ✅ Verified | ✅ Swift 6 native |
| **Dependency Size** | Larger (24 deps) | Smaller (focused) |

**Recommendation**: Use **opentelemetry-swift** for this project (iOS/macOS target, URLSession compatibility)

---

## Integration Strategy

### Option 1: Extend Existing Infrastructure with OpenTelemetry Exporters (Recommended)

**Approach**: Keep existing `DistributedTracing.swift`, `MetricsCollector.swift`, middleware stack. Add OpenTelemetry OTLP exporters as backends.

**Implementation**:
1. Add `opentelemetry-swift` dependency (OpenTelemetryProtocolExporter only)
2. Implement `OTLPTraceExporter` conforming to existing `TraceExporter` protocol
3. Implement `OTLPMetricsExporter` implementing `MetricsCollector` protocol
4. Map existing span/metric types to OpenTelemetry semantic conventions
5. Configure OTLP endpoint (collector URL, headers, auth)

**Advantages**:
- ✅ Minimal disruption to existing codebase
- ✅ Preserves existing W3C Trace Context implementation
- ✅ Keeps middleware architecture intact
- ✅ No behavioral changes to request/response flow
- ✅ Existing tests remain valid
- ✅ Gradual rollout (console exporter → OTLP exporter)

**Disadvantages**:
- ⚠️ Maintains custom tracing abstraction (not pure OpenTelemetry API)
- ⚠️ Requires mapping layer between our types and OTel types
- ⚠️ May miss some OpenTelemetry features (baggage, links, etc.)

**Effort Estimate**: 2-3 days (1 day exporter impl, 1 day testing, 0.5 day docs)

---

### Option 2: Full OpenTelemetry SDK Integration

**Approach**: Replace existing tracing/metrics with OpenTelemetry SDK. Use OpenTelemetry API throughout.

**Implementation**:
1. Add `opentelemetry-swift` dependency (full SDK)
2. Replace `TraceContext`/`TraceSpan` with `OTel.Span`
3. Replace `MetricsCollector` with OpenTelemetry Metrics API
4. Rewrite `TracingMiddleware` using OpenTelemetry Tracer
5. Configure OpenTelemetry SDK initialization
6. Migrate all existing tests to OpenTelemetry test patterns

**Advantages**:
- ✅ Full OpenTelemetry feature set (baggage, span links, context)
- ✅ Standard API (easier for users familiar with OTel)
- ✅ Future-proof (follows industry standard)
- ✅ Better interoperability with other OTel libraries

**Disadvantages**:
- ❌ Large refactor (380 lines `DistributedTracing.swift` replaced)
- ❌ Breaking API changes (users must update)
- ❌ All existing tests must be rewritten
- ❌ Risk of introducing regressions
- ❌ Potential URLSession instrumentation conflict (our middleware vs theirs)
- ❌ Larger dependency footprint (24 transitive deps)

**Effort Estimate**: 7-10 days (3 days refactor, 3 days testing, 2 days docs, 2 days migration guide)

---

### Option 3: Hybrid Approach (Custom + OTel Backend)

**Approach**: Keep existing W3C Trace Context, add OpenTelemetry backend exporters, expose OpenTelemetry API for advanced users.

**Implementation**:
1. Add `opentelemetry-swift` (API + OTLP exporter only)
2. Implement `OTLPTraceExporter` for existing `TraceSpan`
3. Add optional `OpenTelemetryTracerProvider` initialization
4. Provide both APIs: existing (simple) + OpenTelemetry (advanced)
5. Document migration path from simple → OTel API

**Advantages**:
- ✅ No breaking changes (existing API preserved)
- ✅ OpenTelemetry available for power users
- ✅ Gradual migration path
- ✅ Smaller initial scope (exporter only)

**Disadvantages**:
- ⚠️ Two APIs to maintain (complexity)
- ⚠️ Confusion for users (which API to use?)
- ⚠️ Eventual deprecation needed

**Effort Estimate**: 4-5 days (2 days dual API, 2 days testing, 1 day docs)

---

## Recommended Approach: Option 1 (Extend with OTel Exporters)

**Rationale**:
1. **Minimal Risk**: No breaking changes, existing tests valid
2. **Fast to Ship**: 2-3 day effort vs 7-10 days for full refactor
3. **Production Ready**: Existing infrastructure is mature (915 lines `MetricsCollector`, 820 lines `NetworkObservabilityMiddleware`)
4. **Phase Scope**: OBS-03 only requires "swift-otel integration", not "full OTel SDK replacement"
5. **Future-Proof**: Can refactor to full OTel API in v2 if needed

---

## Implementation Plan Outline

### Task 1: Add OpenTelemetry Dependency

**File**: `/Packages/Networking/Package.swift`

```swift
dependencies: [
  // Existing deps...
  .package(
    url: "https://github.com/open-telemetry/opentelemetry-swift.git",
    from: "2.3.0"
  ),
]

targets: [
  .target(
    name: "Networking",
    dependencies: [
      // Existing deps...
      .product(name: "OpenTelemetryProtocolExporter", package: "opentelemetry-swift"),
      .product(name: "ResourceExtension", package: "opentelemetry-swift"),
    ]
  )
]
```

**Reasoning**: Only import OTLP exporter and resource extension, not full SDK (smaller footprint)

---

### Task 2: Implement OTLPTraceExporter

**New File**: `/Packages/Networking/Sources/Networking/OTLPTraceExporter.swift`

**Responsibilities**:
- Conform to existing `TraceExporter` protocol
- Convert `TraceSpan` → OpenTelemetry `Span` protobuf
- Map W3C trace context → OTLP trace/span IDs
- Batch spans for efficient export
- Handle retries/backoff for failed exports
- Support gRPC and HTTP protocols

**Key Mappings**:
```swift
// TraceContext → OTLP
traceContext.traceId → span.trace_id (bytes)
traceContext.spanId → span.span_id (bytes)
traceContext.parentSpanId → span.parent_span_id (bytes)
traceContext.traceFlags → span.flags

// TraceSpan → OTLP Span
span.name → span.name
span.startTime → span.start_time_unix_nano
span.endTime → span.end_time_unix_nano
span.status → span.status (SpanStatus enum)
span.attributes → span.attributes (KeyValue[])
span.events → span.events (Event[])
```

**Configuration**:
```swift
public struct OTLPConfiguration: Sendable {
  let endpoint: String           // "http://localhost:4318/v1/traces"
  let headers: [String: String]  // Auth headers
  let timeout: TimeInterval      // Default: 10s
  let batchSize: Int             // Default: 100 spans
  let protocol: Protocol         // .grpc or .http

  enum Protocol { case grpc, http }
}
```

---

### Task 3: Implement OTLPMetricsCollector

**New File**: `/Packages/Networking/Sources/Networking/OTLPMetricsCollector.swift`

**Responsibilities**:
- Conform to existing `MetricsCollector` protocol
- Convert `ObservabilityEvent` → OpenTelemetry Metrics
- Convert `PerformanceMetrics` → OpenTelemetry Metrics
- Aggregate metrics into time-series
- Export to OTLP endpoint

**Metric Mappings**:
```swift
// PerformanceMetrics → OTLP Metrics
totalRequests → Counter "http.client.request.count"
averageResponseTime → Histogram "http.client.duration"
errorRate → Gauge "http.client.error_rate"
throughput → Gauge "http.client.throughput"
activeConnections → Gauge "http.client.active_requests"
```

**Semantic Conventions**: Follow OpenTelemetry HTTP semantic conventions (https://opentelemetry.io/docs/specs/semconv/http/http-spans/)

---

### Task 4: Add Resource Attributes

**Modification**: Enhance `NetworkObservabilityMiddleware.Configuration`

**New Fields**:
```swift
public struct Configuration: Sendable {
  // Existing fields...

  // New: Resource attributes (service metadata)
  let serviceName: String             // "my-ios-app"
  let serviceVersion: String          // "1.2.3"
  let serviceEnvironment: String      // "production"
  let serviceInstanceId: String?      // UUID or device ID
  let deploymentEnvironment: String?  // "staging", "prod"
}
```

**Resource Mapping**: Use OpenTelemetry `Resource` type from ResourceExtension

---

### Task 5: Update TracingMiddleware for OTLP

**Modification**: `/Packages/Networking/Sources/Networking/DistributedTracing.swift`

**Changes**:
- Add optional `OTLPTraceExporter` in addition to generic `TraceExporter`
- Attach resource attributes to spans
- Add HTTP semantic convention attributes:
  - `http.method` → request.method
  - `http.url` → request.url
  - `http.status_code` → response.status
  - `http.request.body.size` → request.body?.count
  - `http.response.body.size` → response.body?.count
  - `net.peer.name` → request.url.host
  - `net.peer.port` → request.url.port

**No Breaking Changes**: Existing API preserved, OTLP is an optional exporter

---

### Task 6: Configuration API

**New File**: `/Packages/Networking/Sources/Networking/OTLPConfiguration.swift`

**Builder Pattern**:
```swift
let otlpConfig = OTLPConfiguration {
  Endpoint("https://otel-collector.example.com:4318/v1/traces")
  Headers(["Authorization": "Bearer \(apiKey)"])
  Timeout(15.0)
  BatchSize(200)
  Protocol(.http)
}

let exporter = OTLPTraceExporter(configuration: otlpConfig)
let tracingMiddleware = TracingMiddleware(exporter: exporter)

let client = NetworkClient {
  BaseURL("https://api.example.com")
  AddMiddleware(tracingMiddleware)
}
```

**Environment-Based Config**:
```swift
// Read from environment variables (production pattern)
let otlpConfig = OTLPConfiguration.fromEnvironment()
// Reads: OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_EXPORTER_OTLP_HEADERS
```

---

### Task 7: Testing Strategy

**Unit Tests**:
- `OTLPTraceExporterTests.swift`: Span conversion, batching, retry logic
- `OTLPMetricsCollectorTests.swift`: Metric conversion, aggregation
- `OTLPConfigurationTests.swift`: Environment parsing, validation

**Integration Tests**:
- Mock OTLP collector endpoint (HTTP server)
- Verify protobuf format (decode received spans/metrics)
- Test end-to-end flow: request → span → OTLP export

**Property-Based Tests**:
- Trace ID generation (ensure 16-byte uniqueness)
- Span batching (verify no data loss)
- Timestamp conversion (Unix nano precision)

---

### Task 8: Documentation

**Files to Create/Update**:
1. **Getting Started**: `Documentation.docc/Observability.md`
   - Quick setup with OTLP exporter
   - Example configurations (local collector, cloud vendor)
   - Viewing traces in Jaeger/Zipkin/Honeycomb

2. **API Reference**: DocC comments on all public types
   - `OTLPTraceExporter`
   - `OTLPMetricsCollector`
   - `OTLPConfiguration`

3. **Migration Guide**: `Documentation.docc/MigrationToOTLP.md`
   - Console exporter → OTLP exporter
   - Configuration patterns
   - Troubleshooting

4. **Examples**: `Examples/ObservabilityExample/`
   - Complete working example with local OTLP collector
   - Docker Compose setup (collector + Jaeger)

---

## Technical Considerations

### 1. Dependency Size Impact

**Current**: Networking package has minimal dependencies (NetworkingMacros only)

**After Addition**:
```
opentelemetry-swift (2.3.0)
├── grpc-swift (1.15.0+)
│   └── swift-nio (2.x)
│   └── swift-nio-http2
│   └── swift-nio-ssl
│   └── swift-protobuf
└── 24 total transitive dependencies
```

**Mitigation**: Import only `OpenTelemetryProtocolExporter` (subset), not full SDK

**Build Time**: Expect +15-30s initial build (cached afterward)

---

### 2. Concurrency Safety

**opentelemetry-swift Status**: ✅ Zero data race errors (verified by Swift Package Index)

**Integration Points**:
- `OTLPTraceExporter` → Must be `Sendable` (conforms to `TraceExporter`)
- `OTLPMetricsCollector` → Actor or struct (conforms to `MetricsCollector`)
- Batching/buffering → Use actor-isolated state

**Verification**: Run with `-enable-actor-data-race-checks` (already in Package.swift)

---

### 3. Performance Impact

**Span Creation Overhead**:
- Current: ~50 µs per span (in-memory only)
- With OTLP: +10-20 µs (protobuf serialization)
- Total: ~70 µs per request (negligible for network I/O)

**Batching Strategy**:
- Batch 100 spans before export (configurable)
- Export every 5 seconds (configurable)
- Async export (non-blocking)

**Memory Usage**:
- Span buffer: ~1 KB per span × 100 = 100 KB
- Protobuf encoding: ~2x span size during serialization
- Total: ~300 KB peak memory (acceptable)

---

### 4. Error Handling

**Export Failures**:
```swift
// Retry with exponential backoff
let retryStrategy = ExponentialBackoff(
  initialDelay: 1.0,
  maxDelay: 60.0,
  maxAttempts: 5
)

// Drop spans after max retries (prevent memory leak)
// Log to OSLog for debugging
```

**Network Failures**:
- Queue spans in memory (up to max buffer size)
- Persist to disk if buffer full (optional)
- Resume export when connectivity restored

---

### 5. Sampling Strategy

**Current**: Simple boolean sampling in `NetworkObservabilityMiddleware.Configuration.tracingSampleRate`

**Enhancement Options**:
1. **Head-based sampling** (current): Decide at span creation
2. **Tail-based sampling**: Decide after span completion (complex, out of scope)
3. **Probability sampling**: Random % (current implementation)
4. **Rate limiting**: Max N spans per second

**Recommendation**: Keep existing probability sampling (0.0-1.0), add rate limiter in v2

---

## Security Considerations

### 1. Sensitive Data in Spans

**Risk**: Span attributes may contain PII (user IDs, tokens in URLs)

**Mitigation**:
- Existing header redaction (`redactedHeaders` set)
- Extend to URL query parameters (redact `?token=...`)
- Attribute allowlist (only export known-safe attributes)

**Configuration**:
```swift
public struct OTLPConfiguration {
  let redactedAttributes: Set<String> = [
    "http.request.header.authorization",
    "http.request.header.cookie",
    "user.id",  // Example: redact user ID
  ]
}
```

---

### 2. OTLP Endpoint Authentication

**Supported Methods**:
- Bearer token in headers (`Authorization: Bearer <token>`)
- API key in headers (`X-API-Key: <key>`)
- mTLS (client certificate authentication)

**Configuration**:
```swift
// Option 1: Headers
OTLPConfiguration {
  Endpoint("https://collector.example.com:4318")
  Headers(["Authorization": "Bearer \(ProcessInfo.processInfo.environment["OTEL_TOKEN"]!)"])
}

// Option 2: mTLS (future enhancement)
OTLPConfiguration {
  Endpoint("https://collector.example.com:4318")
  ClientCertificate(certPath, keyPath)
}
```

**Secret Management**: Document use of environment variables, not hardcoded tokens

---

### 3. Data Retention

**Collector-Side**: OTLP exporter sends data to collector (not responsible for retention)

**Client-Side Buffering**:
- In-memory only by default (no disk persistence)
- Optional disk persistence for offline scenarios (encrypted)

---

## Open Questions for Planning Phase

1. **OTLP Protocol Choice**: gRPC or HTTP?
   - **gRPC**: More efficient, requires grpc-swift dependency
   - **HTTP**: Simpler, fewer dependencies, easier debugging
   - **Recommendation**: HTTP for v1, gRPC as opt-in

2. **Metrics API**: Should we implement OpenTelemetry Metrics or just export via OTLP?
   - **Current**: Custom `MetricsCollector` protocol
   - **Option A**: Keep custom, add OTLP exporter (recommended)
   - **Option B**: Migrate to OpenTelemetry Metrics API (large scope)

3. **Resource Attributes**: How should users configure service.name, service.version?
   - **Option A**: Explicit configuration in `OTLPConfiguration`
   - **Option B**: Auto-detect from Bundle.main (iOS apps)
   - **Option C**: Both (auto-detect with override)

4. **Backwards Compatibility**: Should existing `ConsoleTraceExporter` remain default?
   - **Yes**: No breaking changes, OTLP is opt-in
   - **No**: Make OTLP default (breaking, requires migration guide)

5. **Test Coverage Target**: What % coverage for new OTLP code?
   - **Recommendation**: 90%+ (OTLP exporter is critical infrastructure)

---

## Success Criteria

### Phase 4 Completion Checklist

- [ ] **OBS-03**: swift-otel integration via `OTLPTraceExporter`
- [ ] Spans exported to OTLP endpoint (HTTP protocol)
- [ ] Metrics exported to OTLP endpoint
- [ ] W3C Trace Context headers continue to work
- [ ] Resource attributes attached to spans (service.name, etc.)
- [ ] HTTP semantic conventions applied
- [ ] Configuration API documented
- [ ] Integration test with mock OTLP collector
- [ ] Zero data race errors with `-enable-actor-data-race-checks`
- [ ] Documentation with examples (local collector setup)
- [ ] No breaking changes to existing API

### Performance Targets

- Span creation overhead: <100 µs per request
- Export latency: <50ms p95 (async, non-blocking)
- Memory overhead: <500 KB for 1000 buffered spans
- Zero blocking of request/response flow

### Quality Targets

- Test coverage: >90% for new OTLP code
- SwiftLint: Zero warnings
- SwiftFormat: Zero formatting issues
- Concurrency: Zero actor data race warnings

---

## References

### OpenTelemetry Resources

1. **Official Specs**:
   - W3C Trace Context: https://www.w3.org/TR/trace-context/
   - OpenTelemetry Protocol (OTLP): https://opentelemetry.io/docs/specs/otlp/
   - HTTP Semantic Conventions: https://opentelemetry.io/docs/specs/semconv/http/

2. **Swift Packages**:
   - opentelemetry-swift: https://github.com/open-telemetry/opentelemetry-swift
   - Swift Package Index: https://swiftpackageindex.com/open-telemetry/opentelemetry-swift
   - swift-otel: https://github.com/swift-otel/swift-otel

3. **Documentation**:
   - Swift Instrumentation Guide: https://opentelemetry.io/docs/languages/swift/instrumentation/
   - URLSession Instrumentation: https://github.com/open-telemetry/opentelemetry-swift/tree/main/Sources/Instrumentation/URLSession

### Project Files

- `DistributedTracing.swift`: W3C Trace Context implementation
- `MetricsCollector.swift`: Metrics collection system
- `NetworkObservabilityMiddleware.swift`: Request/response observability
- `LoggingMiddleware.swift`: Structured logging
- `REQUIREMENTS.md`: OBS-01 through OBS-07 definitions

---

## Conclusion

Phase 4 Observability implementation is **primarily integration work**, not ground-up development. The codebase has robust distributed tracing (W3C Trace Context), comprehensive metrics collection, and structured logging. The missing piece is **OBS-03: swift-otel integration**, which requires:

1. Adding `opentelemetry-swift` dependency (OTLP exporter only)
2. Implementing `OTLPTraceExporter` (conforms to existing `TraceExporter`)
3. Implementing `OTLPMetricsCollector` (conforms to existing `MetricsCollector`)
4. Mapping existing types to OpenTelemetry semantic conventions
5. Adding resource attributes (service name, version, environment)
6. Providing configuration API (endpoint, headers, protocol)

**Estimated Effort**: 2-3 days implementation + 1 day testing + 0.5 day documentation = **3.5-4.5 days total**

**Risk**: Low (no breaking changes, existing infrastructure mature)

**Next Step**: Create detailed PLAN.md with task breakdown, file modifications, and acceptance criteria.

---

**Research Status**: ✅ Complete - Ready for Phase Planning

**Researcher Notes**: Existing observability infrastructure is production-quality. Recommend Option 1 (extend with OTLP exporters) over full OpenTelemetry SDK refactor. Focus on HTTP protocol for simplicity, defer gRPC to v2.
