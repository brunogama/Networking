# Phase 1 Plan: Swift 6 Concurrency Compliance

**Phase**: 1 of 6
**Goal**: Achieve bullet-proof Swift 6 strict concurrency with zero warnings
**Requirements**: CONC-01 through CONC-10
**Status**: Ready for execution

## Success Criteria

1. `swift build -Xswiftc -warnings-as-errors` passes with zero warnings
2. All public types are `Sendable` (grep confirms no non-Sendable public types)
3. Zero `Thread.sleep` in codebase (grep confirms)
4. Zero `@unchecked Sendable` without documented justification
5. All actors audited for reentrancy with fix patterns applied

## Task Breakdown

### Wave 1: Fix Compilation Errors (Critical Path)

**Task 1.1: Fix AuthenticationMiddleware.swift:164**
- **File**: `Sources/Networking/AuthenticationMiddleware.swift`
- **Issue**: `await self.clearRefreshTask()` but `clearRefreshTask()` is not async
- **Fix**: Remove `await` or make method async if needed
- **LOC**: ~5 lines changed

**Task 1.2: Fix ProgressTracking.swift:265,275**
- **File**: `Sources/Networking/ProgressTracking.swift`
- **Issue**: `await cleanupStream(transferId)` but `cleanupStream()` is not async
- **Fix**: Remove `await` keyword
- **LOC**: ~5 lines changed

### Wave 2: Core Sendable Compliance (High Priority)

**Task 2.1: Convert KeychainService to actor**
- **File**: `Sources/Networking/KeychainService.swift`
- **Current**: `class KeychainService: @unchecked Sendable`
- **Fix**: Convert to `actor KeychainService` with async methods
- **Impact**: API change (methods become async)
- **LOC**: ~30 lines changed

**Task 2.2: Make InternalCachedResponse immutable struct**
- **File**: `Sources/Networking/NetworkClient.swift`
- **Current**: `class InternalCachedResponse: @unchecked Sendable`
- **Fix**: Convert to `struct InternalCachedResponse: Sendable` with let properties
- **LOC**: ~15 lines changed

**Task 2.3: Make TraceSpan immutable struct**
- **File**: `Sources/Networking/DistributedTracing.swift`
- **Current**: `class TraceSpan: @unchecked Sendable`
- **Fix**: Convert to `struct TraceSpan: Sendable` with let properties
- **Impact**: May need to adjust usage patterns
- **LOC**: ~40 lines changed

### Wave 3: Continuation Audit (Medium Priority)

**Task 3.1: Audit AsyncSemaphore continuation management**
- **File**: `Sources/Networking/CachingMiddleware.swift`
- **Check**: Ensure all stored continuations are resumed exactly once
- **Risk**: Continuation leak if actor deallocates with waiters
- **Fix**: Add deinit cleanup or use structured approach
- **LOC**: ~20 lines changed

**Task 3.2: Audit ResponseTransformation continuations**
- **File**: `Sources/Networking/ResponseTransformation.swift`
- **Issue**: Nested Task inside continuation - review for exactly-once resume
- **Pattern**: Continuation wrapping sync code - could simplify to pure async
- **LOC**: ~30 lines changed

### Wave 4: Actor Reentrancy Audit (Medium Priority)

**Task 4.1: Audit AuthenticationMiddleware.TokenManager**
- **File**: `Sources/Networking/AuthenticationMiddleware.swift`
- **Pattern**: Token refresh with in-flight tracking
- **Check**: Verify check-then-act patterns across await points
- **Risk**: Double refresh if not properly tracked
- **LOC**: ~20 lines if fixes needed

**Task 4.2: Audit CachingMiddleware**
- **File**: `Sources/Networking/CachingMiddleware.swift`
- **Pattern**: Cache get/set operations
- **Check**: Verify no stale reads after await
- **LOC**: ~15 lines if fixes needed

**Task 4.3: Audit WebSocketClient state transitions**
- **File**: `Sources/Networking/WebSocketClient.swift`
- **Pattern**: Connection state machine
- **Check**: Verify state transitions are atomic
- **Current**: Already uses proper Task cancellation
- **LOC**: ~10 lines if fixes needed

### Wave 5: Task Lifecycle Management (Medium Priority)

**Task 5.1: Manage unmanaged Task {} in AuthenticationMiddleware**
- **File**: `Sources/Networking/AuthenticationMiddleware.swift`
- **Current**: Fire-and-forget Task in defer
- **Fix**: Store task reference or use structured concurrency
- **LOC**: ~15 lines changed

**Task 5.2: Manage unmanaged Task {} in ProgressTracking**
- **File**: `Sources/Networking/ProgressTracking.swift`
- **Current**: Fire-and-forget cleanup tasks
- **Fix**: Store task references for cancellation
- **LOC**: ~20 lines changed

**Task 5.3: Manage unmanaged Task {} in TransferControls**
- **File**: `Sources/Networking/TransferControls.swift`
- **Current**: Fire-and-forget state transition tasks
- **Fix**: Store task references
- **LOC**: ~15 lines changed

### Wave 6: Document Justified @unchecked Sendable (Lower Priority)

**Task 6.1: Document nonisolated(unsafe) justification**
- **File**: `Sources/Networking/FileTransferOperations.swift`
- **Current**: `nonisolated(unsafe) private var backgroundSession: URLSession?`
- **Action**: Add documentation comment explaining safety
- **LOC**: ~5 lines

**Task 6.2: Document test utilities @unchecked Sendable**
- **Files**: Testing/*.swift, BDD/**/*.swift
- **Action**: Add inline comments justifying each usage
- **Rationale**: Test utilities need flexibility, acceptable with documentation
- **LOC**: ~20 lines total

### Wave 7: Verification

**Task 7.1: Run full build verification**
```bash
swift build -Xswiftc -warnings-as-errors
```

**Task 7.2: Run all tests**
```bash
swift test
```

**Task 7.3: Grep verification**
```bash
# Verify no Thread.sleep
rg "Thread\.sleep" --type swift Sources/

# Verify @unchecked Sendable is documented
rg "@unchecked Sendable" --type swift Sources/ -B 2

# Verify no non-Sendable public types (manual review)
```

## Dependencies

```
Wave 1 (Compilation) ──► Wave 2 (Core Sendable)
          │                      │
          ▼                      ▼
     Wave 3 (Continuations)  Wave 4 (Reentrancy)
               │                   │
               └─────────┬─────────┘
                         ▼
                 Wave 5 (Task Lifecycle)
                         │
                         ▼
                Wave 6 (Documentation)
                         │
                         ▼
                 Wave 7 (Verification)
```

## Estimated Impact

| Metric | Before | After |
|--------|--------|-------|
| Compilation errors | 2 | 0 |
| @unchecked Sendable (core, unjustified) | 3 | 0 |
| nonisolated(unsafe) (undocumented) | 1 | 0 |
| Unmanaged Task {} | 5 | 0 |
| Actors with reentrancy issues | TBD | 0 |

## Files to Modify

1. `Sources/Networking/AuthenticationMiddleware.swift` - Wave 1, 4, 5
2. `Sources/Networking/ProgressTracking.swift` - Wave 1, 5
3. `Sources/Networking/KeychainService.swift` - Wave 2
4. `Sources/Networking/NetworkClient.swift` - Wave 2
5. `Sources/Networking/DistributedTracing.swift` - Wave 2
6. `Sources/Networking/CachingMiddleware.swift` - Wave 3, 4
7. `Sources/Networking/ResponseTransformation.swift` - Wave 3
8. `Sources/Networking/WebSocketClient.swift` - Wave 4
9. `Sources/Networking/TransferControls.swift` - Wave 5
10. `Sources/Networking/FileTransferOperations.swift` - Wave 6
11. `Sources/Networking/Testing/*.swift` - Wave 6

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking API changes | High | Medium | Document migration, keep old APIs deprecated |
| Test failures | Medium | Low | Fix tests alongside code |
| Actor reentrancy bugs discovered | Medium | High | In-flight tracking pattern |
| Performance regression | Low | Medium | Benchmark critical paths |

## Acceptance Criteria

- [ ] `swift build -Xswiftc -warnings-as-errors` exits 0
- [ ] `swift test` exits 0
- [ ] `rg "Thread\.sleep" --type swift Sources/` returns empty
- [ ] All `@unchecked Sendable` have inline documentation
- [ ] All actors have reentrancy audit comments
- [ ] All Task {} instances are managed or documented as fire-and-forget
- [ ] No continuation resume paths that could hang or crash

---
*Plan created: 2026-02-14*
*Estimated tasks: 17*
*Estimated LOC changed: ~250-300*
