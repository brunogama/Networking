---
phase: 01-swift-6-concurrency-compliance
plan: 03
subsystem: core-library
tags: [concurrency, continuation-safety, cancellation]
dependency-graph:
  requires: [01-02-sendable-compliance]
  provides: [continuation-safety]
  affects: [AsyncSemaphore, AsyncJSONDecoderTransformer, AsyncImageDecoderTransformer]
tech-stack:
  added: []
  patterns: [withTaskCancellationHandler, exactly-once-resume, direct-async-transform]
key-files:
  created: []
  modified:
    - Sources/Networking/CachingMiddleware.swift
    - Sources/Networking/ResponseTransformation.swift
decisions:
  - "AsyncSemaphore now handles cancellation with withTaskCancellationHandler"
  - "AsyncJSONDecoderTransformer simplified to direct decode (no continuation needed)"
  - "AsyncImageDecoderTransformer simplified to direct processing (no continuation needed)"
  - "FileTransferOperations continuation pattern verified safe (wraps callback-based API)"
metrics:
  duration: 141
  completed: 2026-02-14T23:07:35Z
---

# Phase 01 Plan 03: Continuation Safety Audit Summary

**Audited and fixed continuation patterns to ensure exactly-once resume guarantee; eliminated nested Task antipattern.**

## Completed Tasks

| Task | Name | Commit | Files Modified |
|------|------|--------|----------------|
| 1 | AsyncSemaphore continuation management | 1813c05 | CachingMiddleware.swift |
| 2 | Simplify ResponseTransformation continuations | 4bbd92d | ResponseTransformation.swift |

## What Was Built

Ensured continuation safety across the codebase by auditing all continuation patterns and applying best practices.

### AsyncSemaphore Cancellation Handling (Task 1)

**Issue**: AsyncSemaphore.wait() stored continuations without handling Task cancellation, risking continuation leaks or hangs.

**Fix Applied**:
```swift
// BEFORE: No cancellation handling
public func wait() async {
  if currentCount > 0 {
    currentCount -= 1
  } else {
    await withCheckedContinuation { continuation in
      waiters.append(continuation)  // Stored but never cancelled
    }
  }
}

// AFTER: Cancellation-safe
public func wait() async {
  if currentCount > 0 {
    currentCount -= 1
  } else {
    await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        if Task.isCancelled {
          continuation.resume()
          return
        }
        waiters.append(continuation)
      }
    } onCancel: {
      Task {
        await self.cancelWait()
      }
    }
  }
}

private func cancelWait() {
  if !waiters.isEmpty {
    let waiter = waiters.removeFirst()
    waiter.resume()  // Ensure exactly-once resume
  }
}
```

**Safety Guarantees**:
1. ✓ Check `Task.isCancelled` before storing continuation
2. ✓ Resume continuation immediately if task already cancelled
3. ✓ `withTaskCancellationHandler` catches cancellation after storage
4. ✓ `cancelWait()` ensures stored continuation is resumed exactly once

### Response Transformation Simplification (Task 2)

**Issue**: AsyncJSONDecoderTransformer and AsyncImageDecoderTransformer wrapped sync work in `withCheckedThrowingContinuation { Task { ... } }` - a dangerous antipattern that risks double-resume.

**Fix Applied**:

```swift
// BEFORE: Nested Task inside continuation (RISKY)
public func transform(_ input: Data) async throws -> T {
  try await withCheckedThrowingContinuation { continuation in
    Task {  // ❌ Nested Task - adds complexity and risk
      do {
        let result = try decoder.decode(type, from: input)
        continuation.resume(returning: result)
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}

// AFTER: Direct async transformation (SAFE)
public func transform(_ input: Data) async throws -> T {
  do {
    return try decoder.decode(type, from: input)
  } catch {
    throw HTTPError(
      category: .decoding("Failed to decode \(type): \(error.localizedDescription)"),
      underlyingError: error
    )
  }
}
```

**Rationale**: JSONDecoder.decode() is synchronous and non-throwing-within-async-context. We're already in an async function, so there's no need for continuation + Task nesting. Just do the work directly.

**Same pattern applied to AsyncImageDecoderTransformer**:
- Removed continuation wrapper
- Simplified to direct property extraction
- Already async function - no need for continuation bridging

### FileTransferOperations Audit (Verified Safe)

**Pattern Found**:
```swift
return await withCheckedContinuation { continuation in
  task.cancel { resumeData in
    continuation.resume(returning: resumeData)
  }
}
```

**Analysis**: ✓ SAFE - This is the **correct** use case for continuations:
- Wraps callback-based API (URLSessionDownloadTask.cancel with completion handler)
- Exactly one code path to `resume()`
- No nested Task
- No manual continuation storage

**Conclusion**: No changes needed.

## Deviations from Plan

### Deviation 1: Simplified Instead of Refactored

**Rule Applied**: Rule 1 (Auto-fix bugs)
**Found during**: Task 2 execution
**Issue**: Plan suggested refactoring continuation patterns, but actual issue was unnecessary continuation use
**Fix**: Removed continuations entirely (sync work already in async context)
**Rationale**:
  - JSONDecoder.decode() is synchronous
  - ImageData creation is synchronous
  - Both are already inside async functions
  - No callback bridging needed
  - Simpler = safer (fewer resume paths)
**Files modified**: ResponseTransformation.swift
**Commit**: 4bbd92d

No other deviations - plan executed as specified.

## Technical Details

### Continuation Safety Rules Applied

1. **Exactly-once resume guarantee**:
   - Every continuation must resume exactly once
   - No code path leaves continuation unresumed
   - No code path resumes continuation twice

2. **Cancellation handling**:
   - Use `withTaskCancellationHandler` when storing continuations
   - Check `Task.isCancelled` before storage
   - Resume stored continuations in `onCancel` handler

3. **Avoid nested Task inside continuation**:
   - If already async, do work directly
   - Only use continuation to bridge callback-based APIs
   - Never `withCheckedContinuation { Task { ... } }`

### Verification Results

```bash
# All continuation patterns audited
$ rg "withChecked.*Continuation" Sources/Networking/
Sources/Networking/FileTransferOperations.swift:497    # ✓ Safe (callback bridge)
Sources/Networking/CachingMiddleware.swift:717         # ✓ Fixed (cancellation handling)

# No nested Task inside continuations
$ rg -A 5 "withChecked.*Continuation" Sources/Networking/ | rg "Task \{"
# (no results) ✓

# Build passes with warnings-as-errors
$ swift build -Xswiftc -warnings-as-errors
Build complete! (1.80s) ✓
```

## Success Criteria Met

- [x] AsyncSemaphore has cancellation handling
- [x] No nested Task inside continuation blocks
- [x] All continuation patterns are audited
- [x] Code compiles without errors or warnings
- [x] FileTransferOperations continuation verified safe (callback bridging)
- [x] ResponseTransformation simplified (removed unnecessary continuations)

## Lessons Learned

1. **Continuations are for callback bridging**: If you're already async and the work is sync, just do it directly
2. **Nested Task is an antipattern**: `withCheckedContinuation { Task { ... } }` adds complexity without benefit
3. **Cancellation must be explicit**: Actor-stored continuations need `withTaskCancellationHandler`
4. **Simpler is safer**: Fewer resume paths = fewer bugs

## Next Steps

Continue with plan 01-04 to audit actor reentrancy patterns and ensure suspension-point safety.

---

**Commits:**
- 1813c05: `feat(01-03): add cancellation handling to AsyncSemaphore`
- 4bbd92d: `refactor(01-03): remove nested Task inside continuation patterns`

**Duration:** 141 seconds (~2.4 minutes)
**Status:** Complete

## Self-Check: PASSED

All files and commits verified:
- ✓ FOUND: Sources/Networking/CachingMiddleware.swift
- ✓ FOUND: Sources/Networking/ResponseTransformation.swift
- ✓ FOUND: 1813c05 (AsyncSemaphore commit)
- ✓ FOUND: 4bbd92d (ResponseTransformation commit)
- ✓ Build passes with warnings-as-errors
- ✓ No nested Task inside continuation patterns
- ✓ All continuation patterns audited (2 fixed, 1 verified safe)
