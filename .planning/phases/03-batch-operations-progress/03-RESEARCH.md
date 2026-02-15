# Phase 03: Batch Operations & Progress - Research

**Researched:** 2026-02-15
**Domain:** Swift 6 structured concurrency, TaskGroup parallel execution, AsyncSequence progress streaming
**Confidence:** HIGH

## Summary

Phase 03 implements batch operations with configurable concurrency limits and progress tracking using AsyncSequence. The existing codebase already has partial implementations: `BatchOperations.swift` provides a TaskGroup-based batch executor, and `ProgressTracking.swift` has a sophisticated AsyncThrowingStream-based progress system. The phase extends these to meet all requirements (BATCH-01 through BATCH-05, PROG-01 through PROG-05).

**Current State Analysis:**
- ✅ `BatchOperations.swift` exists with TaskGroup implementation (BATCH-01, BATCH-04 done)
- ✅ `ProgressTracking.swift` exists with AsyncStream and actor-based management (PROG-01, PROG-02 foundation)
- ❌ `maxConcurrency` in `BatchConfiguration` is NOT enforced (BATCH-02 missing)
- ❌ No resumable download integration in batch context (PROG-05 incomplete)
- ⚠️ URLSessionDownloadDelegate exists but uses completion handlers (needs async wrapper)

**Primary recommendation:** Enhance existing implementations rather than creating new systems. Use `withThrowingTaskGroup(of:returning:body:)` with manual concurrency limiting via async semaphore pattern. Wrap URLSessionDownloadDelegate callbacks with CheckedContinuation for progress streaming.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift Standard Library | 6.0+ | TaskGroup, AsyncSequence, actors | Built-in structured concurrency primitives |
| Foundation URLSession | iOS 16+ | URLSessionDownloadTask, delegates | Apple's async/await integration (iOS 15+) |
| Swift Concurrency Runtime | 6.0+ | Actor isolation, Sendable enforcement | Compiler-verified thread safety |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| XCTest + swift-testing | Built-in | Test async sequences, TaskGroup behavior | All test cases for this phase |
| SwiftCheck | 0.12+ | Property-based testing for concurrency | Testing race conditions, partial failures |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| TaskGroup | OperationQueue | TaskGroup is Swift 6 native, better cancellation propagation |
| AsyncSequence | Combine Publishers | AsyncSequence is lighter, no framework dependency |
| Actor-based state | NSLock + class | Actors are compiler-verified safe, Sendable-enforced |
| CheckedContinuation | Notification-based | Continuations integrate natively with async/await |

**Installation:**
```bash
# No external dependencies needed - all Swift Standard Library
swift build -Xswiftc -warnings-as-errors
```

## Architecture Patterns

### Recommended Project Structure
```
Sources/Networking/
├── BatchOperations.swift       # ✅ EXISTS - TaskGroup executor
├── ProgressTracking.swift      # ✅ EXISTS - AsyncStream progress
├── ProgressTrackingMiddleware.swift  # ✅ EXISTS - Actor-based middleware
├── FileTransferOperations.swift      # ✅ EXISTS - Download delegate
└── [NEW] BatchConcurrencyLimiter.swift  # NEEDED for BATCH-02
```

### Pattern 1: TaskGroup with Concurrency Limiting
**What:** Use `withThrowingTaskGroup` with actor-isolated semaphore to enforce `maxConcurrency`

**When to use:** BATCH-01, BATCH-02 (configurable concurrency limit)

**Example:**
```swift
// Source: Swift Concurrency documentation + existing BatchOperations.swift
public func executeBatch(
  _ requests: [HTTPRequest],
  configuration: BatchConfiguration = .default
) async -> [BatchResult] {
  guard !requests.isEmpty else { return [] }

  // Concurrency limiter actor
  let limiter = ConcurrencyLimiter(maxConcurrency: configuration.maxConcurrency)

  return await withTaskGroup(of: (Int, HTTPRequest, Result<HTTPResponse, HTTPError>).self) { group in
    for (index, request) in requests.enumerated() {
      group.addTask {
        // Wait for available slot
        await limiter.acquire()
        defer { Task { await limiter.release() } }

        do {
          let response = try await self.execute(request)
          return (index, request, .success(response))
        } catch let error as HTTPError {
          return (index, request, .failure(error))
        }
      }
    }

    var results: [BatchResult] = []
    for await (index, request, result) in group {
      results.append(BatchResult(index: index, request: request, result: result))
    }

    // Sort to preserve original order (BATCH-04)
    return results.sorted { $0.index < $1.index }
  }
}

// Actor-based semaphore (recommended pattern from Swift Forums)
actor ConcurrencyLimiter {
  private let maxConcurrency: Int
  private var currentCount = 0

  init(maxConcurrency: Int) {
    self.maxConcurrency = maxConcurrency == 0 ? Int.max : maxConcurrency
  }

  func acquire() async {
    while currentCount >= maxConcurrency {
      await Task.yield()  // Cooperative suspension
    }
    currentCount += 1
  }

  func release() {
    currentCount -= 1
  }
}
```

### Pattern 2: AsyncThrowingStream for Progress
**What:** Existing `ProgressTracking.ProgressStreamManager` actor creates AsyncThrowingStream for progress updates

**When to use:** PROG-01, PROG-02 (upload/download progress as AsyncSequence)

**Example:**
```swift
// Source: ProgressTracking.swift (already implemented)
let streamManager = ProgressTracking.ProgressStreamManager()

// Create progress stream
let progressStream = await streamManager.createProgressStream(
  for: transferId,
  totalBytes: expectedSize
)

// Consume progress updates
for try await update in progressStream {
  print("Progress: \(update.progress * 100)% - \(update.formattedSpeed)")

  // update.transferredBytes (PROG-03)
  // update.totalBytes (PROG-03)
  // update.progress (PROG-04 - fraction 0.0 to 1.0)
}
```

### Pattern 3: URLSessionDownloadDelegate Async Wrapper
**What:** Wrap delegate callbacks with CheckedContinuation for async/await integration

**When to use:** PROG-05 (resumable downloads) - existing FileTransferOperations.BackgroundTransferDelegate

**Example:**
```swift
// Source: Apple WWDC23 "Build robust and resumable file transfers"
actor DownloadProgressBridge {
  private var continuations: [URLSessionTask: AsyncStream<ProgressUpdate>.Continuation] = [:]

  func createProgressStream(for task: URLSessionDownloadTask) -> AsyncStream<ProgressUpdate> {
    AsyncStream { continuation in
      continuations[task] = continuation

      continuation.onTermination = { @Sendable [weak self] _ in
        Task { await self?.removeContinuation(for: task) }
      }
    }
  }

  // Called from URLSessionDownloadDelegate
  func didWriteData(
    task: URLSessionDownloadTask,
    bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpected: Int64
  ) {
    guard let continuation = continuations[task] else { return }

    let progress = ProgressUpdate(
      transferId: UUID(),  // Use task identifier
      phase: .downloading,
      totalBytes: totalBytesExpected,
      transferredBytes: totalBytesWritten
    )

    continuation.yield(progress)
  }

  func didFinishDownloading(task: URLSessionDownloadTask, location: URL) {
    continuations[task]?.finish()
    continuations.removeValue(forKey: task)
  }

  private func removeContinuation(for task: URLSessionTask) {
    continuations.removeValue(forKey: task)
  }
}
```

### Pattern 4: Partial Failure Handling
**What:** Collect all results regardless of individual failures, return Result<T, E> per item

**When to use:** BATCH-03 (partial failure handling), BATCH-05 (cancellation propagation)

**Example:**
```swift
// Source: BatchOperations.swift (already implemented correctly)
public struct BatchResult: Sendable {
  public let index: Int
  public let request: HTTPRequest
  public let result: Result<HTTPResponse, HTTPError>

  public var isSuccess: Bool {
    if case .success = result { return true }
    return false
  }
}

// Usage pattern
let results = await client.executeBatch(requests)

// Separate successes and failures
let successes = results.compactMap { $0.response }
let failures = results.compactMap { $0.error }

print("Completed: \(successes.count), Failed: \(failures.count)")
```

### Anti-Patterns to Avoid
- **Don't use DispatchQueue/OperationQueue**: TaskGroup is Swift 6 native and provides better cancellation
- **Don't use Combine for progress**: AsyncSequence is lighter and doesn't require framework import
- **Don't block on `await` in delegate callbacks**: Use fire-and-forget Task for continuation updates
- **Don't force-unwrap in async context**: All optionals must be guarded (Swift 6 strict mode)
- **Don't ignore cancellation**: TaskGroup propagates cancellation automatically, respect it

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Concurrency limiting | Custom dispatch queue throttling | Actor-based semaphore pattern | Compiler-verified actor isolation prevents data races |
| Progress streaming | Custom delegate + NotificationCenter | AsyncThrowingStream | Native async/await integration, automatic backpressure |
| Partial failure collection | Custom error aggregator | Result<T, E> array | Type-safe, compiler-checked, standard library |
| Resumable downloads | Custom chunk tracking | URLSessionDownloadTask.resumeData | Handles HTTP Range requests, partial downloads, server validation |
| Cancellation | Manual cancellation tokens | TaskGroup cancellation | Automatic propagation, cooperative cancellation, structured |

**Key insight:** Swift 6 structured concurrency eliminates most custom async patterns. TaskGroup handles parallelism, actors handle shared state, AsyncSequence handles streaming. Custom solutions introduce data race risks that strict concurrency mode will reject.

## Common Pitfalls

### Pitfall 1: Ignoring maxConcurrency Configuration
**What goes wrong:** Current `BatchOperations.swift` ignores `configuration.maxConcurrency`, spawns unlimited tasks

**Why it happens:** `withTaskGroup` doesn't enforce limits by default

**How to avoid:** Implement actor-based semaphore (see Pattern 1 above)

**Warning signs:**
- Memory pressure when batching 100+ requests
- Server rate limiting errors (429 responses)
- Network connection pool exhaustion

### Pitfall 2: URLSessionDelegate Threading Issues
**What goes wrong:** Delegate callbacks run on URLSession's delegate queue, not actor-isolated

**Why it happens:** URLSessionDownloadDelegate is Objective-C protocol, predates Swift concurrency

**How to avoid:** Bridge with `@unchecked Sendable` + actor-isolated continuation storage (see Pattern 3)

**Warning signs:**
- Compiler warning: "Capture of 'self' with non-sendable type in @Sendable closure"
- Data race runtime warnings with `-enable-actor-data-race-checks`
- Progress updates arriving out of order

### Pitfall 3: Progress Stream Memory Leaks
**What goes wrong:** AsyncThrowingStream continuations never finish, retain cycles

**Why it happens:** Forgot to call `continuation.finish()` on completion/cancellation

**How to avoid:** Always use `onTermination` handler to clean up (existing `ProgressTracking.swift` does this correctly)

**Warning signs:**
- Memory usage grows with each batch operation
- Instruments shows leaking AsyncThrowingStream objects
- Active transfer count never decreases

### Pitfall 4: Cancellation Not Propagated
**What goes wrong:** TaskGroup cancelled but individual tasks keep running

**Why it happens:** Didn't check `Task.isCancelled` inside task body

**How to avoid:** Swift 6 TaskGroup propagates automatically, but check before expensive operations

**Warning signs:**
- Tasks complete after TaskGroup returns
- Network requests not cancelled when user dismisses view
- Server logs show requests after client stopped

### Pitfall 5: Order Preservation Breaking
**What goes wrong:** Batch results returned in completion order, not request order

**Why it happens:** `for await` on TaskGroup yields in completion order

**How to avoid:** Store index with result, sort before returning (BATCH-04 requirement)

**Warning signs:**
- Results array has different order than requests array
- Test failures: `results[0]` doesn't match `requests[0]`
- UI shows files in wrong order

## Code Examples

Verified patterns from official sources:

### TaskGroup Parallel Execution (BATCH-01)
```swift
// Source: Apple Swift Concurrency documentation
// CORRECT: Basic parallel execution pattern
await withTaskGroup(of: BatchResult.self) { group in
  for (index, request) in requests.enumerated() {
    group.addTask {
      do {
        let response = try await self.execute(request)
        return BatchResult(index: index, request: request, result: .success(response))
      } catch let error as HTTPError {
        return BatchResult(index: index, request: request, result: .failure(error))
      }
    }
  }

  var results: [BatchResult] = []
  for await result in group {
    results.append(result)
  }
  return results.sorted { $0.index < $1.index }
}
```

### Progress Tracking with AsyncSequence (PROG-01, PROG-02)
```swift
// Source: ProgressTracking.swift (existing implementation)
// CORRECT: Create and consume progress stream
let progressStream = await streamManager.createProgressStream(
  for: transferId,
  totalBytes: fileSize
)

// Update progress from URLSessionDelegate
try await streamManager.updateProgress(
  for: transferId,
  transferredBytes: currentBytes,
  phase: .downloading
)

// Consumer side
for try await update in progressStream {
  print("[\(update.transferId)] \(update.progress * 100)%")
  print("Speed: \(update.formattedSpeed)")
  print("ETA: \(update.formattedTimeRemaining)")
}
```

### Resumable Downloads (PROG-05)
```swift
// Source: Apple WWDC23 "Build robust and resumable file transfers"
// CORRECT: URLSession resumable download pattern
func downloadResumable(from url: URL) async throws -> URL {
  let task = session.downloadTask(with: url)

  // Create progress bridge
  let progressStream = await progressBridge.createProgressStream(for: task)

  // Start download
  task.resume()

  // Monitor progress
  Task {
    for await progress in progressStream {
      print("Downloaded: \(progress.transferredBytes) / \(progress.totalBytes ?? 0)")
    }
  }

  // Wait for completion
  let (location, response) = try await task.result  // iOS 15+ async API
  return location
}

// Resume interrupted download
func resumeDownload(with resumeData: Data) async throws -> URL {
  let task = session.downloadTask(withResumeData: resumeData)
  task.resume()

  let (location, response) = try await task.result
  return location
}
```

### Cancellation Handling (BATCH-05)
```swift
// Source: Swift Concurrency documentation
// CORRECT: Automatic cancellation propagation
let batchTask = Task {
  await client.executeBatch(requests, configuration: config)
}

// Cancel entire batch
batchTask.cancel()  // Propagates to all child tasks in TaskGroup

// Inside task body - check cancellation
group.addTask {
  if Task.isCancelled { return .cancelled(request) }

  let response = try await self.execute(request)

  // Check again after expensive operation
  if Task.isCancelled { return .cancelled(request) }

  return .success(response)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Completion handlers | async/await | Swift 5.5 (2021) | Eliminates callback hell, compiler-checked |
| Dispatch queues | Structured concurrency (TaskGroup) | Swift 5.5 (2021) | Automatic cancellation propagation |
| NotificationCenter progress | AsyncSequence | Swift 5.5 (2021) | Type-safe, backpressure-aware streaming |
| NSLock/DispatchQueue | Actors | Swift 5.5 (2021) | Compiler-verified data race safety |
| Optional Sendable | Strict Sendable enforcement | Swift 6.0 (2024) | Compile-time concurrency verification |
| `@escaping` closures | `@Sendable` closures | Swift 5.5 (2021) | Prevents data races across isolation domains |

**Deprecated/outdated:**
- **URLSession completion handlers**: Use async `data(from:)` / `download(from:)` (iOS 15+)
- **Operation dependencies**: Use TaskGroup child tasks instead
- **DispatchSemaphore for async limiting**: Use actor-based semaphore (prevents thread pool exhaustion)
- **Combine Publishers for progress**: AsyncSequence is lighter, no framework import required

## Open Questions

1. **Should batch operations support priority ordering?**
   - What we know: TaskGroup doesn't guarantee execution order
   - What's unclear: Should high-priority requests start first?
   - Recommendation: Defer to Phase 5+ (not in MVP requirements). Use index-based ordering for now.

2. **How to handle HTTP/2 multiplexing with concurrency limits?**
   - What we know: URLSession automatically uses HTTP/2 when available
   - What's unclear: Does server multiplexing interact with our client-side `maxConcurrency`?
   - Recommendation: Trust URLSession's connection pool management. Our `maxConcurrency` is application-level limit, not connection-level.

3. **Should progress updates be throttled to avoid UI overload?**
   - What we know: Existing `ProgressTrackingConfiguration` has `maxUpdateInterval` (0.1s default)
   - What's unclear: Is this sufficient for batch operations with 50+ concurrent transfers?
   - Recommendation: Keep existing throttling. Aggregate progress actor already handles this correctly.

4. **How to test race conditions in TaskGroup concurrency?**
   - What we know: Swift Testing supports async tests, SwiftCheck has concurrency primitives
   - What's unclear: Best practices for deterministic race testing in CI
   - Recommendation: Use property-based tests with `@Test(arguments: [1, 2, 4, 8, 16])` for various concurrency levels. Run with Thread Sanitizer in CI.

## Sources

### Primary (HIGH confidence)
- Swift Concurrency Documentation (developer.apple.com/documentation/swift/concurrency) - TaskGroup, AsyncSequence patterns
- WWDC23 "Build robust and resumable file transfers" (developer.apple.com/videos/play/wwdc2023/10006/) - URLSessionDownloadTask best practices
- WWDC23 "Beyond the basics of structured concurrency" (developer.apple.com/videos/play/wwdc2023/10170/) - TaskGroup advanced patterns
- Swift Forums thread "Reporting progress on async function" (forums.swift.org/t/74174) - AsyncStream progress patterns
- Existing codebase: `BatchOperations.swift`, `ProgressTracking.swift`, `FileTransferOperations.swift` - Production patterns

### Secondary (MEDIUM confidence)
- Kodeco "Modern Concurrency in Swift" Chapter 7 (kodeco.com) - TaskGroup tutorial with examples
- Matteo Manferdini "AsyncStream and AsyncSequence for Swift Concurrency" (matteomanferdini.com/swift-asyncstream/) - AsyncStream patterns
- Hacking with Swift "Structured concurrency" (hackingwithswift.com/swift/5.5/structured-concurrency) - Concurrency fundamentals
- Medium "Replace Progress Closures with AsyncStream" (medium.com/@shial184686) - Migration patterns

### Tertiary (LOW confidence, flagged for validation)
- StackOverflow "Should a single failure fail a bulk operation?" - General pattern discussion (not Swift-specific)
- LinkedIn post on TaskGroup error handling - Brief example, no production testing mentioned

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All Swift Standard Library built-ins, no external dependencies
- Architecture: HIGH - Existing implementations verified in codebase, official Apple patterns documented
- Pitfalls: HIGH - Based on Swift Forums discussions, official migration guides, and existing code comments

**Research date:** 2026-02-15
**Valid until:** 30 days (Swift 6 stable, URLSession API mature)

**Critical findings:**
1. **maxConcurrency enforcement is missing** in current `BatchOperations.swift` - MUST be added
2. URLSessionDownloadDelegate requires `@unchecked Sendable` + actor bridge pattern
3. Progress streaming foundation exists and is well-architected (AsyncThrowingStream pattern)
4. Resumable downloads already partially implemented via `FileTransferOperations.resumeTransfer`
5. All requirements (BATCH-01 to BATCH-05, PROG-01 to PROG-05) are achievable with Swift Standard Library only
