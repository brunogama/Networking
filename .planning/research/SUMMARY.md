# Research Summary: Networking Framework Modernization

## Key Findings

### Stack (Swift 6 Concurrency)

**Primary recommendation**: Swift 6.2+ with default actor isolation enabled.

| Component | Choice | Status |
|-----------|--------|--------|
| Concurrency | Actors + Structured | Partially done |
| Transport | URLSession async/await | Done |
| Tracing | swift-otel 1.0 | In progress |
| Testing | XCTest + SwiftCheck + Quick | Done |

**Critical path**: Actor isolation for all mutable state. URLSession already async-first.

### Features (Table Stakes vs Differentiators)

**Table stakes** (must have):
1. Native async/await API — DONE
2. Type-safe request building — DONE (result builders)
3. Interceptor chain — DONE (9+ implementations)
4. Retry with backoff — DONE
5. Mock/test support — DONE
6. **Sendable compliance — PARTIAL (needs audit)**

**Differentiators** (competitive advantage):
1. Swift macros for API generation — IN PROGRESS
2. WebSocket support — IN PROGRESS
3. GraphQL client — IN PROGRESS
4. Batch operations — IN PROGRESS
5. **Distributed tracing — IN PROGRESS**
6. Upload/download progress — NOT STARTED

### Pitfalls (Watch Out For)

**Critical risks**:

1. **Actor reentrancy** — Actors are NOT locks. State can mutate between await points.
   - Mitigation: Use in-flight task tracking, avoid check-then-act patterns

2. **@unchecked Sendable abuse** — Silences compiler without fixing safety.
   - Mitigation: Zero tolerance policy, convert to actors/structs

3. **Continuation misuse** — Resume zero times (hang) or multiple times (crash).
   - Mitigation: Audit all `withContinuation`, use resume tracking

4. **MainActor blocking** — Thread.sleep or sync I/O on main thread.
   - Mitigation: grep for Thread.sleep, use Task.sleep

5. **Task lifecycle leaks** — Unmanaged Task { } instances.
   - Mitigation: Store task references, cancel on deinit

## Build Order Implications

Based on feature dependencies:

```
Phase 1: Sendable + Actor Isolation (foundation)
    ↓
Phase 2: Complete async APIs (depends on actors)
    ↓
Phase 3: WebSocket + GraphQL (depends on async)
    ↓
Phase 4: Observability (depends on everything)
```

## Recommended Approach

### Phase 1: Swift 6 Strict Concurrency (Foundation)
1. Audit all types for Sendable compliance
2. Actor-isolate all mutable state (caches, managers)
3. Remove `Thread.sleep`, use `Task.sleep`
4. Remove `@unchecked Sendable`
5. Audit continuations for exactly-once resume
6. Verify zero warnings with `-warnings-as-errors`

### Phase 2: Developer Experience
1. Polish result builder DSL
2. Complete macro implementations
3. Request composition operators
4. Response processing chains
5. Modern configuration API

### Phase 3: Advanced Features
1. Complete WebSocket client
2. Complete GraphQL client
3. Complete batch operations
4. Add upload/download progress
5. Conditional request support

### Phase 4: Observability & Testing
1. Integrate swift-otel for distributed tracing
2. Add metrics collection
3. Enhanced testing DSL
4. Property-based tests for algorithms
5. DocC documentation

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Actor reentrancy bugs | HIGH | HIGH | Thorough audit, in-flight tracking |
| Breaking API changes | CERTAIN | MEDIUM | Migration guide, deprecation |
| Performance regression | LOW | MEDIUM | Benchmark before/after |
| Incomplete Sendable | MEDIUM | HIGH | Automated grep audit |

## Success Metrics

| Metric | Target |
|--------|--------|
| Compiler warnings | 0 (with -warnings-as-errors) |
| SwiftLint violations | 0 (strict mode) |
| @unchecked Sendable | 0 instances |
| Thread.sleep usage | 0 instances |
| Test coverage | >90% on new code |
| Actor reentrancy issues | 0 (verified by audit) |

## Next Steps

1. **Immediate**: Run Sendable audit on existing codebase
2. **Phase 1**: Complete Swift 6 concurrency compliance
3. **Phase 2**: Polish DX features (macros, builders)
4. **Phase 3**: Complete advanced features (WebSocket, GraphQL)
5. **Phase 4**: Add observability, documentation

---
*Synthesis date: 2026-02-14*
*Sources: STACK.md, FEATURES.md, PITFALLS.md, ARCHITECTURE.md, networking_modernization_analysis.md*
