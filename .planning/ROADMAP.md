# Roadmap: Networking Framework Modernization

## Overview

| Phases | Requirements | Depth |
|--------|--------------|-------|
| 7 | 55+ | Standard |

## Phase Structure

### Phase 0: Audit URLSession and Apple APIs for Async/Await Modernization

**Goal**: Identify all legacy URLSession and Apple API usages that should be refactored to modern async/await patterns.

**Requirements**: AUDIT-01, AUDIT-02, AUDIT-03

**Success Criteria**:
1. Complete inventory of all URLSession callback-based APIs in codebase
2. Complete inventory of all completion handler patterns
3. Document all deprecated Apple API usages (pre-async/await)
4. Prioritized list of refactoring candidates with complexity estimates
5. No blocking issues for Phase 1 concurrency compliance

**Rationale**: Foundation audit to understand the scope of async/await modernization. Must complete before Phase 1 to ensure concurrency compliance work is comprehensive.

**Plans:** 1 plan

Plans:
- [ ] 00-01-PLAN.md — Execute systematic scan and create audit inventory document

---

### Phase 1: Swift 6 Concurrency Compliance ✓

**Status**: COMPLETE (2026-02-14)

**Goal**: Achieve bullet-proof Swift 6 strict concurrency with zero warnings.

**Requirements**: CONC-01, CONC-02, CONC-03, CONC-04, CONC-05, CONC-06, CONC-07, CONC-08, CONC-09, CONC-10

**Success Criteria**:
1. ✓ `swift build -Xswiftc -warnings-as-errors` passes with zero warnings
2. ✓ All public types are `Sendable` (grep confirms no non-Sendable public types)
3. ✓ Zero `Thread.sleep` in codebase (grep confirms)
4. ✓ Zero `@unchecked Sendable` without documented justification (11/11 documented)
5. ✓ All actors audited for reentrancy with fix patterns applied (6 locations)

**Plans Executed**: 7 plans across 7 waves
**Verification**: .planning/phases/01-swift-6-concurrency-compliance/01-VERIFICATION.md

**Rationale**: Foundation for all other phases. Without concurrency compliance, advanced features cannot be safely implemented.

**Depends on**: Phase 0

---

### Phase 2: Developer Experience

**Goal**: Achieve beautiful, ergonomic APIs with minimal boilerplate.

**Requirements**: DX-01, DX-02, DX-03, DX-04, DX-05, DX-06, DX-07, DX-08, DX-09

**Success Criteria**:
1. User can compose requests with `+` operator
2. User can chain response processing (`.decode().cache().retry()`)
3. `@Cacheable` macro generates caching interceptor
4. `@Measured` macro generates timing metrics
5. Phantom types catch HTTP method mismatches at compile time

**Rationale**: DX improvements make the library pleasant to use. Depends on Phase 1 for Sendable closures in builders.

---

### Phase 3: WebSocket & GraphQL

**Goal**: Complete real-time and GraphQL capabilities.

**Requirements**: WS-01, WS-02, WS-03, WS-04, WS-05, WS-06, WS-07, GQL-01, GQL-02, GQL-03, GQL-04, GQL-05, GQL-06

**Success Criteria**:
1. User can connect to WebSocket and receive messages via AsyncSequence
2. User can send WebSocket messages
3. WebSocket reconnects automatically on disconnect
4. User can execute GraphQL query with type-safe response
5. User can execute GraphQL mutation with type-safe response
6. `@Query` and `@Mutation` macros generate boilerplate

**Rationale**: Completes the transport layer options. WebSocket exists in progress, needs polish. GraphQL exists in progress, needs completion.

---

### Phase 4: Batch Operations & Progress

**Goal**: Enable parallel requests and progress tracking.

**Requirements**: BATCH-01, BATCH-02, BATCH-03, BATCH-04, BATCH-05, PROG-01, PROG-02, PROG-03, PROG-04, PROG-05

**Success Criteria**:
1. User can execute multiple requests in parallel with configurable limit
2. Partial failures handled (some succeed, some fail)
3. Results returned in original submission order
4. User can track upload progress via AsyncSequence
5. User can track download progress via AsyncSequence
6. Downloads are resumable

**Rationale**: Advanced networking patterns. Depends on Phase 1 for structured concurrency.

---

### Phase 5: Observability

**Goal**: Enable production monitoring with distributed tracing and metrics.

**Requirements**: OBS-01, OBS-02, OBS-03, OBS-04, OBS-05, OBS-06, OBS-07

**Success Criteria**:
1. Requests create distributed tracing spans
2. Trace context propagates in HTTP headers (W3C Trace Context)
3. swift-otel integration works end-to-end
4. Request timing metrics available
5. Success/failure rates tracked
6. Structured logging captures request/response details

**Rationale**: Production observability. Depends on all transport features to instrument them.

---

### Phase 6: Testing & Documentation

**Goal**: Complete test coverage and documentation for production release.

**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04, TEST-05, TEST-06, TEST-07, DOC-01, DOC-02, DOC-03, DOC-04, DOC-05

**Success Criteria**:
1. Expect/Respond DSL available for test mocking
2. Property-based tests cover retry backoff and interceptor chain
3. BDD specs cover user-facing behaviors
4. DocC catalog generates with all public APIs
5. Getting started guide included
6. Migration guide from legacy APIs included

**Rationale**: Final phase ensures production readiness. Testing validates all features work correctly.

---

## Requirement Mapping

| Phase | Requirements | Count |
|-------|--------------|-------|
| 0 | AUDIT-01 to AUDIT-03 | 3 |
| 1 | CONC-01 to CONC-10 | 10 |
| 2 | DX-01 to DX-09 | 9 |
| 3 | WS-01 to WS-07, GQL-01 to GQL-06 | 13 |
| 4 | BATCH-01 to BATCH-05, PROG-01 to PROG-05 | 10 |
| 5 | OBS-01 to OBS-07 | 7 |
| 6 | TEST-01 to TEST-07, DOC-01 to DOC-05 | 12 |
| **Total** | | **64** |

## Dependencies

```
Phase 0 (Audit) ────────────────────┐
                                    │
Phase 1 (Concurrency) ──────────────┼───┐
                                    │   │
Phase 2 (DX) ───────────────────────┤   ├───► Phase 5 (Observability)
                                    │   │           │
Phase 3 (WebSocket/GraphQL) ────────┤   │           │
                                    │   │           ▼
Phase 4 (Batch/Progress) ───────────┘   └─────► Phase 6 (Testing/Docs)
```

**Critical path**: Phase 0 (audit) must complete first. Phase 1 depends on Phase 0. Phases 2-4 can parallelize after Phase 1. Phase 5 depends on 2-4. Phase 6 is final.

---
*Created: 2026-02-14*
*Total: 7 phases, 64 requirements*
