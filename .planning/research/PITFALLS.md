# Pitfalls Research: Swift 6 Concurrency Gotchas

## Executive Summary

Swift 6 strict concurrency catches many bugs at compile time, but several pitfalls remain. Actor reentrancy is the most dangerous — actors don't prevent data races when methods await and other calls interleave. Other common mistakes include `@unchecked Sendable` abuse, continuation misuse, and MainActor blocking.

## Critical Pitfalls

### 1. Actor Reentrancy (Most Dangerous)

**What it is**: Actors are NOT locks. When an actor method awaits, another call can execute, mutating state unexpectedly.

```swift
// DANGEROUS: Actor reentrancy
actor Cache {
    private var items: [String: Data] = [:]

    func getOrFetch(_ key: String) async throws -> Data {
        if let cached = items[key] {  // Check
            return cached
        }
        let data = try await fetch(key)  // AWAIT: Other calls can run here!
        items[key] = data  // Store - but items[key] might now exist!
        return data
    }
}
```

**Warning signs**:
- Actor method has `await` between read and write of same property
- Multiple concurrent calls to same actor method
- "Check-then-act" patterns across await points

**Prevention**:
```swift
actor Cache {
    private var items: [String: Data] = [:]
    private var inFlight: [String: Task<Data, Error>] = [:]

    func getOrFetch(_ key: String) async throws -> Data {
        if let cached = items[key] {
            return cached
        }
        if let existing = inFlight[key] {
            return try await existing.value  // Reuse existing fetch
        }
        let task = Task { try await fetch(key) }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let data = try await task.value
        items[key] = data
        return data
    }
}
```

**Phase mapping**: Phase 1 (Swift 6 Concurrency) — audit all actors for reentrancy

### 2. @unchecked Sendable Abuse

**What it is**: Using `@unchecked Sendable` to silence compiler without fixing the underlying thread-safety issue.

```swift
// DANGEROUS: Lying to the compiler
class NetworkManager: @unchecked Sendable {
    private var token: String?  // MUTABLE STATE - NOT THREAD SAFE!
}
```

**Warning signs**:
- `@unchecked Sendable` on class with mutable properties
- `@unchecked Sendable` without comment explaining why it's safe
- Multiple instances of `@unchecked Sendable` in codebase

**Prevention**:
- Convert to actor if state must be mutable
- Convert to struct if state can be immutable
- Only use `@unchecked Sendable` for OS types known to be thread-safe (e.g., `DispatchQueue`)

**Phase mapping**: Phase 1 — Sendable audit, remove all @unchecked

### 3. Continuation Misuse

**What it is**: Calling `resume` zero times (hang) or multiple times (crash).

```swift
// DANGEROUS: Resume might never be called
func fetchAsync() async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
        legacyFetch { result in
            if let data = result.data {
                continuation.resume(returning: data)
            }
            // BUG: What if result.data is nil? Continuation never resumes!
        }
    }
}

// DANGEROUS: Resume called multiple times
func fetchAsync() async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
        legacyFetch { result in
            continuation.resume(returning: result.data)  // First resume
        }
        // BUG: What if callback is called twice?
        // continuation.resume(returning: default)  // Crash!
    }
}
```

**Warning signs**:
- Callback has multiple code paths, not all resume
- Callback can be called multiple times
- No flag tracking whether continuation has been resumed

**Prevention**:
```swift
func fetchAsync() async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
        var resumed = false
        legacyFetch { result in
            guard !resumed else { return }
            resumed = true
            switch result {
            case .success(let data):
                continuation.resume(returning: data)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}
```

**Phase mapping**: Phase 1 — audit all `withContinuation` usage

### 4. MainActor Blocking

**What it is**: Calling synchronous code from `@MainActor` context that blocks the main thread.

```swift
@MainActor
class ViewModel {
    func loadData() async {
        // DANGEROUS: Thread.sleep blocks main thread!
        Thread.sleep(forTimeInterval: 1.0)

        // Also dangerous: synchronous file I/O
        let data = try! Data(contentsOf: url)
    }
}
```

**Warning signs**:
- `Thread.sleep` in `@MainActor` context
- Synchronous file/network I/O in `@MainActor` context
- Long-running computation on MainActor

**Prevention**:
```swift
@MainActor
class ViewModel {
    func loadData() async {
        try await Task.sleep(for: .seconds(1))  // Non-blocking

        let data = try await Task.detached {
            try Data(contentsOf: url)  // Off main thread
        }.value
    }
}
```

**Phase mapping**: Phase 1 — grep for `Thread.sleep`, synchronous I/O

### 5. Task Cancellation Ignored

**What it is**: Not checking `Task.isCancelled` in long-running operations.

```swift
func processItems(_ items: [Item]) async {
    for item in items {
        // DANGEROUS: Continues processing even if task cancelled
        await process(item)
    }
}
```

**Warning signs**:
- Loops without cancellation checks
- Long operations without `try Task.checkCancellation()`
- `Task.detached` without cancellation handling

**Prevention**:
```swift
func processItems(_ items: [Item]) async throws {
    for item in items {
        try Task.checkCancellation()
        await process(item)
    }
}
```

**Phase mapping**: Phase 1 — audit async loops

### 6. Isolation Crossing with Mutable State

**What it is**: Passing mutable reference types across actor boundaries.

```swift
class MutableConfig {
    var timeout: TimeInterval = 30
}

actor NetworkClient {
    func execute(config: MutableConfig) async {
        // DANGEROUS: MutableConfig is passed by reference
        // Other code can mutate it while we're using it
        let timeout = config.timeout  // Race condition!
    }
}
```

**Warning signs**:
- Class types (not structs) passed to actor methods
- `inout` parameters on async functions
- Captured mutable references in `@Sendable` closures

**Prevention**:
```swift
struct ImmutableConfig: Sendable {
    let timeout: TimeInterval
}

actor NetworkClient {
    func execute(config: ImmutableConfig) async {
        // Safe: ImmutableConfig is Sendable value type
        let timeout = config.timeout
    }
}
```

**Phase mapping**: Phase 1 — audit all actor method parameters

### 7. Unstructured Task Leaks

**What it is**: Creating `Task { }` without managing lifecycle, leading to resource leaks.

```swift
class ViewModel {
    func startPolling() {
        // DANGEROUS: Task runs forever, no way to cancel
        Task {
            while true {
                await fetchUpdates()
                try await Task.sleep(for: .seconds(5))
            }
        }
    }

    deinit {
        // Task keeps running after ViewModel is deallocated!
    }
}
```

**Warning signs**:
- `Task { }` without storing reference
- Infinite loops in tasks
- No cancellation on deinit

**Prevention**:
```swift
class ViewModel {
    private var pollingTask: Task<Void, Never>?

    func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                await fetchUpdates()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    deinit {
        pollingTask?.cancel()
    }
}
```

**Phase mapping**: Phase 1 — audit all `Task { }` usage

## Medium-Risk Pitfalls

### 8. AsyncSequence Back-Pressure

Producing faster than consuming causes memory growth.

**Prevention**: Use `AsyncStream` with bounded buffer.

### 9. nonisolated(unsafe)

New in Swift 6.2, allows unsafe access. Treat like `@unchecked Sendable`.

**Prevention**: Avoid unless absolutely necessary, document why.

### 10. withTaskGroup Ordering

Results come in completion order, not submission order.

**Prevention**: Pair results with identifiers if order matters.

## Audit Checklist

Before Phase 1 completion, verify:

- [ ] All actors audited for reentrancy (check-then-act across await)
- [ ] Zero `@unchecked Sendable` without justification
- [ ] All continuations resume exactly once
- [ ] No `Thread.sleep` anywhere
- [ ] All `Task { }` have managed lifecycle
- [ ] All actor parameters are Sendable value types
- [ ] Async loops check cancellation
- [ ] No mutable class instances cross isolation

---
*Research date: 2026-02-14*
*Sources: Hacking with Swift, Swift Forums, LinkedIn articles, Medium*
