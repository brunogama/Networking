# Requirements: Networking Framework Modernization

## v1 Requirements

### Concurrency (CONC)

- [ ] **CONC-01**: All public types must be `Sendable` (audit and fix)
- [ ] **CONC-02**: All mutable shared state must be actor-isolated
- [ ] **CONC-03**: All closures at isolation boundaries must be `@Sendable`
- [ ] **CONC-04**: Zero `Thread.sleep` usage (replace with `Task.sleep`)
- [ ] **CONC-05**: Zero `@unchecked Sendable` without documented justification
- [ ] **CONC-06**: All continuations must resume exactly once (audit)
- [ ] **CONC-07**: All `Task { }` instances must have managed lifecycle
- [ ] **CONC-08**: Zero compiler warnings with `-warnings-as-errors`
- [ ] **CONC-09**: Actor reentrancy audit (check-then-act patterns)
- [ ] **CONC-10**: All async loops must check `Task.isCancelled`

### Developer Experience (DX)

- [ ] **DX-01**: Request composition operators (`+` for combining requests)
- [ ] **DX-02**: Response processing chains (`.decode().cache().retry()`)
- [ ] **DX-03**: `@Cacheable` macro for automatic response caching
- [ ] **DX-04**: `@Measured` macro for automatic timing metrics
- [ ] **DX-05**: Phantom types for compile-time HTTP method safety
- [ ] **DX-06**: Phantom types for compile-time environment safety
- [ ] **DX-07**: Modern fluent configuration API (result builder)
- [ ] **DX-08**: `@Query` macro for GraphQL queries
- [ ] **DX-09**: `@Mutation` macro for GraphQL mutations

### WebSocket (WS)

- [ ] **WS-01**: Async stream for receiving messages
- [ ] **WS-02**: Send method for transmitting messages
- [ ] **WS-03**: Connection state management (connecting, connected, disconnected)
- [ ] **WS-04**: Automatic reconnection with exponential backoff
- [ ] **WS-05**: Ping/pong health check support
- [ ] **WS-06**: Graceful disconnection handling
- [ ] **WS-07**: Message encoding/decoding (Codable support)

### GraphQL (GQL)

- [ ] **GQL-01**: Query execution with variable injection
- [ ] **GQL-02**: Mutation execution with variable injection
- [ ] **GQL-03**: Error extraction from GraphQL response
- [ ] **GQL-04**: Type-safe response decoding
- [ ] **GQL-05**: Query/mutation macro code generation
- [ ] **GQL-06**: Subscription support via WebSocket

### Batch Operations (BATCH)

- [ ] **BATCH-01**: Parallel request execution
- [ ] **BATCH-02**: Configurable concurrency limit
- [ ] **BATCH-03**: Partial failure handling (some succeed, some fail)
- [ ] **BATCH-04**: Result aggregation with original order
- [ ] **BATCH-05**: Cancellation propagation

### Progress Tracking (PROG)

- [ ] **PROG-01**: Upload progress as AsyncSequence
- [ ] **PROG-02**: Download progress as AsyncSequence
- [ ] **PROG-03**: Progress includes bytes transferred and total
- [ ] **PROG-04**: Progress includes fraction completed
- [ ] **PROG-05**: Resumable download support

### Observability (OBS)

- [ ] **OBS-01**: Distributed tracing span creation
- [ ] **OBS-02**: Trace context propagation in headers
- [ ] **OBS-03**: swift-otel integration
- [ ] **OBS-04**: Request timing metrics
- [ ] **OBS-05**: Success/failure rate metrics
- [ ] **OBS-06**: Request count by endpoint
- [ ] **OBS-07**: Structured logging for requests/responses

### Testing (TEST)

- [ ] **TEST-01**: Expect builder for request matching
- [ ] **TEST-02**: Respond builder for response stubbing
- [ ] **TEST-03**: Sequential expectation chaining
- [ ] **TEST-04**: Property-based tests for retry backoff
- [ ] **TEST-05**: Property-based tests for interceptor chain
- [ ] **TEST-06**: BDD specs for user-facing behaviors
- [ ] **TEST-07**: Integration tests for component interactions

### Documentation (DOC)

- [ ] **DOC-01**: DocC catalog with articles
- [ ] **DOC-02**: Getting started guide
- [ ] **DOC-03**: Migration guide from legacy APIs
- [ ] **DOC-04**: API reference for all public types
- [ ] **DOC-05**: Code examples for common patterns

## v2 Requirements (Deferred)

- Background transfer support
- Certificate pinning configuration DSL
- GraphQL subscription batching
- Offline-first caching strategy
- Response compression handling

## Out of Scope

- **gRPC support** — REST/GraphQL/WebSocket sufficient for v1
- **Combine integration** — Async/await supersedes it, technical debt
- **RxSwift integration** — Third-party reactive obsolete
- **Custom HTTP parser** — URLSession handles this well
- **Mobile-specific features** — Background transfers deferred to v2
- **Third-party logging** — Use built-in OSLog

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| CONC-01 to CONC-10 | TBD | Pending |
| DX-01 to DX-09 | TBD | Pending |
| WS-01 to WS-07 | TBD | Pending |
| GQL-01 to GQL-06 | TBD | Pending |
| BATCH-01 to BATCH-05 | TBD | Pending |
| PROG-01 to PROG-05 | TBD | Pending |
| OBS-01 to OBS-07 | TBD | Pending |
| TEST-01 to TEST-07 | TBD | Pending |
| DOC-01 to DOC-05 | TBD | Pending |

---
*Created: 2026-02-14*
*Total: 55 requirements across 9 categories*
