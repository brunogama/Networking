# Stack Research: Swift 6 Concurrency & Modern Networking

## Executive Summary

Swift 6.2 introduces "approachable concurrency" with default actor isolation, making strict concurrency the standard. Modern networking libraries must embrace actor isolation, `@Sendable` closures, and structured concurrency throughout. The 2025/2026 stack centers on:

- **Swift 6.2+** with default actor isolation enabled
- **URLSession** async/await APIs (native since iOS 15)
- **swift-otel 1.0** for distributed tracing (released Sept 2025)
- **Actor-isolated state** replacing locks/queues

## Recommended Stack (2026)

### Core Runtime

| Component | Choice | Version | Rationale |
|-----------|--------|---------|-----------|
| Swift Version | Swift 6.2+ | 6.2 | Default actor isolation, approachable concurrency |
| Concurrency Model | Actors + Structured | Native | Compiler-verified thread safety |
| HTTP Transport | URLSession | iOS 15+ | Native async/await, no wrapper needed |
| Networking Architecture | Actor-isolated | Native | No locks, no queues, no GCD |

### Observability

| Component | Choice | Version | Rationale |
|-----------|--------|---------|-----------|
| Distributed Tracing | swift-otel | 1.0.0 | Official OpenTelemetry SDK, stable |
| Metrics | swift-metrics | 2.x | SwiftNIO ecosystem, Apple-maintained |
| Logging | OSLog | Native | Zero allocation, privacy-aware |

### Testing

| Component | Choice | Version | Rationale |
|-----------|--------|---------|-----------|
| Unit Testing | XCTest + Testing | Native | Swift Testing macro-based assertions |
| Property Testing | SwiftCheck | 0.14+ | QuickCheck-style property testing |
| BDD Testing | Quick/Nimble | 7.x | Behavior-driven specs |
| Macro Testing | swift-macro-testing | 0.4+ | PointFree macro expansion testing |

### Code Quality

| Component | Choice | Version | Rationale |
|-----------|--------|---------|-----------|
| Formatter | swift-format | 600+ | Swift 6 compatible |
| Linter | SwiftLint | 0.58+ | Swift 6 rules, strict mode |
| AST Library | swift-syntax | 600+ | Macro implementation |

## Swift 6 Concurrency Patterns

### Default Actor Isolation (Swift 6.2)

```swift
// Swift 6.2 default: MainActor isolation for entry points
// Use @globalActor for domain-specific isolation

@globalActor
public actor NetworkActor {
    public static let shared = NetworkActor()
}

@NetworkActor
final class NetworkClient {
    // All methods implicitly @NetworkActor isolated
}
```

### Sendable Requirements

All types crossing isolation boundaries must be `Sendable`:

```swift
// Value types: automatic Sendable if all properties Sendable
public struct HTTPRequest: Sendable {
    let method: HTTPMethod
    let url: URL
    let headers: [String: String]
    let body: Data?
}

// Reference types: must be actor or immutable
public actor ResponseCache: Sendable {
    private var cache: [String: CachedResponse] = [:]
}
```

### Structured Concurrency

```swift
// TaskGroup for parallel requests
func fetchAll(ids: [String]) async throws -> [User] {
    try await withThrowingTaskGroup(of: User.self) { group in
        for id in ids {
            group.addTask { try await fetchUser(id: id) }
        }
        return try await group.reduce(into: []) { $0.append($1) }
    }
}

// AsyncSequence for streams
func subscribe() -> AsyncThrowingStream<Message, Error> {
    AsyncThrowingStream { continuation in
        // Stream implementation
    }
}
```

### Continuation Patterns

```swift
// Wrap callback APIs safely
func legacyFetch() async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
        legacyAPI.fetch { result in
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

## What NOT to Use

| Anti-Pattern | Why | Alternative |
|--------------|-----|-------------|
| `DispatchQueue` | Swift 6 prefers actors | Actor isolation |
| `NSLock`/`os_unfair_lock` | Manual thread safety | Actor isolation |
| `Thread.sleep` | Blocks thread | `Task.sleep` |
| Completion handlers | Callback hell, no Sendable | async/await |
| `@unchecked Sendable` | Bypasses compiler | Fix underlying issue |
| Global mutable state | Data races | Actor-isolated state |

## Confidence Levels

| Recommendation | Confidence | Notes |
|----------------|------------|-------|
| Swift 6.2 default isolation | HIGH | Apple's official direction |
| Actor isolation for state | HIGH | Compiler-verified safety |
| swift-otel 1.0 | HIGH | Just hit 1.0, production-ready |
| URLSession async/await | HIGH | Native, battle-tested |
| swift-metrics | MEDIUM | Good but limited iOS adoption |
| Quick/Nimble | MEDIUM | Works but Swift Testing catching up |

---
*Research date: 2026-02-14*
*Sources: SwiftLee, Hacking with Swift, Swift Forums, OpenTelemetry docs*
