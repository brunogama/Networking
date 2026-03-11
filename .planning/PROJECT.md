# Networking Framework Modernization

## What This Is

A complete modernization of the Networking Swift framework to achieve bullet-proof Swift 6 strict concurrency compliance, modern developer experience with result builders and macros, advanced features (WebSocket, GraphQL, batch operations), and comprehensive observability. This is an existing ~49k LOC production library being upgraded with breaking API changes allowed.

## Core Value

Every public API must be thread-safe by construction (actor-isolated or immutable Sendable types) with zero data race potential — verified by Swift 6 strict concurrency checking and manual audit.

## Requirements

### Validated

<!-- Existing capabilities confirmed working -->

- [x] Async/await HTTP execution — existing
- [x] Interceptor chain architecture (9+ implementations) — existing
- [x] Result builder for request construction — existing
- [x] @API/@GET/@POST/@PUT/@DELETE macros — existing
- [x] MockNetworkClient and MockURLProtocol for testing — existing
- [x] HTTPError with recovery categories — existing
- [x] KeychainService for secure token storage — existing

### Active

<!-- Current scope: Full modernization across 4 phases -->

**Phase 1: Swift 6 Strict Concurrency**
- [ ] Audit all types for Sendable compliance
- [ ] Actor-isolate all mutable shared state
- [ ] Mark all cross-isolation closures @Sendable
- [ ] Eliminate Thread.sleep, use Task.sleep
- [ ] Verify zero warnings with -warnings-as-errors
- [ ] NetworkActor global actor for shared state

**Phase 2: Developer Experience Revolution**
- [ ] Request builder DSL with result builders
- [ ] Modern configuration API (fluent builder)
- [ ] Phantom types for compile-time safety
- [ ] Enhanced macro support (@Cacheable, @Measured)
- [ ] Request composition operators (+, |>)
- [ ] Response processing chains (.decode().cache().retry())

**Phase 3: Advanced Features**
- [ ] WebSocket client with async streams
- [ ] GraphQL client with @Query/@Mutation macros
- [ ] Batch operations (parallel request execution)
- [ ] Built-in caching with invalidation
- [ ] Upload/download progress tracking
- [ ] Circuit breaker pattern
- [ ] Conditional requests (ETag, If-Modified-Since)

**Phase 4: Observability & Testing**
- [ ] Built-in metrics (timing, success/failure rates)
- [ ] Distributed tracing (span propagation)
- [ ] Enhanced testing DSL (Expect/Respond builders)
- [ ] Property-based tests for all algorithms
- [ ] BDD tests for user-facing behaviors
- [ ] Integration tests for component interactions

### Out of Scope

- Mobile-specific features (background transfers) — focus on core networking
- Third-party logging framework integration — use built-in OSLog
- gRPC support — REST/GraphQL/WebSocket sufficient for v1
- Custom transport layers — URLSession only

## Context

**Existing Codebase:**
- ~49k lines of Swift code
- Already has interceptor chain, result builders, macros
- Some Swift 6 compliance work started (NetworkActor, WebSocketClient in progress)
- Strong test infrastructure (62 test files)

**Technical Environment:**
- Swift 6.0+ with strict concurrency checking
- iOS 16+, macOS 13+, tvOS 16+, watchOS 9+
- Swift Package Manager distribution
- Dependencies: swift-syntax (macros), Quick/Nimble (BDD), SwiftCheck (property tests)

**Known Issues to Address:**
- Completion handler legacy patterns (convert to async)
- Manual Thread.sleep usage (convert to Task.sleep)
- Potential shared mutable state not actor-isolated
- Some types missing Sendable conformance

## Constraints

- **Swift Version**: Swift 6.0+ only — use all structured concurrency features
- **Concurrency Model**: Actor isolation mandatory for mutable state — no locks/queues
- **API Stability**: Breaking changes allowed — provide migration guide
- **Testing**: Comprehensive coverage required (unit + property + BDD + integration)
- **Linting**: SwiftLint strict mode, RULES.md compliance, warnings-as-errors
- **Documentation**: DocC for all public APIs

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Actor isolation over locks | Swift 6 native, compiler-verified safety | — Pending |
| Breaking API changes | Clean modern APIs worth migration cost | — Pending |
| URLSession-only transport | Avoid abstraction complexity, proven reliable | — Pending |
| Result builders for DSL | Native Swift, great IDE support | — Pending |

---
*Last updated: 2026-02-14 after initialization*
