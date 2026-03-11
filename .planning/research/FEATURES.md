# Features Research: Modern Networking Libraries

## Executive Summary

Modern Swift networking libraries (Alamofire 5+, Moya, Get, async-http-client) have converged on async/await, result builders, and actor-isolated state. Table stakes in 2025/2026 include native concurrency, type-safe request building, and comprehensive testing support. Differentiators are macros for API generation, built-in observability, and WebSocket/GraphQL support.

## Table Stakes Features

These features are expected by developers in 2025/2026. Missing any means developers choose another library.

### 1. Native Async/Await API

**Complexity**: LOW (existing codebase already has this)

```swift
func execute(_ request: HTTPRequest) async throws -> HTTPResponse
```

- All public APIs must be async
- No completion handlers in public interface
- Structured concurrency support (TaskGroup, cancellation)

### 2. Type-Safe Request Building

**Complexity**: MEDIUM (result builders require design)

```swift
let request = HTTPRequest {
    GET("/users/\(id)")
    Header("Authorization", "Bearer \(token)")
    QueryParam("include", "profile")
}
```

- Result builder DSL
- Compile-time validation
- IDE auto-completion

### 3. Interceptor/Middleware Chain

**Complexity**: LOW (existing codebase has this)

- Request transformation (add headers, auth)
- Response processing (caching, logging)
- Error handling (retry, token refresh)
- Ordered execution with short-circuit capability

### 4. Retry with Exponential Backoff

**Complexity**: LOW (existing codebase has this)

- Configurable max attempts
- Exponential backoff with jitter
- Condition-based retry (retry only 5xx, not 4xx)

### 5. Comprehensive Error Handling

**Complexity**: LOW (existing codebase has this)

- Typed error enums
- Recovery suggestions
- Underlying error preservation
- HTTP status code mapping

### 6. Mock/Test Support

**Complexity**: LOW (existing codebase has this)

- Protocol-based HTTPClient abstraction
- In-memory mock for unit tests
- URLProtocol mock for integration tests
- Request expectation matching

### 7. Sendable Compliance

**Complexity**: MEDIUM (audit required)

- All public types must be `Sendable`
- All closures at isolation boundaries must be `@Sendable`
- Zero compiler warnings with `-warnings-as-errors`

## Differentiating Features

These features provide competitive advantage. Not all libraries have them.

### 1. Swift Macros for API Generation

**Complexity**: HIGH (AST manipulation required)

```swift
@API(baseURL: "https://api.example.com")
protocol UserAPI {
    @GET("/users/{id}")
    func getUser(@Path id: String) async throws -> User
}
```

- Zero boilerplate API clients
- Compile-time path parameter validation
- Type-safe request/response binding

**Current status**: Partially implemented in existing codebase

### 2. WebSocket Support

**Complexity**: MEDIUM (separate transport layer)

```swift
let stream = try await client.connect(to: "/chat")
for try await message in stream {
    handle(message)
}
try await stream.send(ChatMessage(text: "Hello"))
```

- AsyncThrowingStream for messages
- Automatic reconnection
- Ping/pong health checks

**Current status**: In progress (WebSocketClient.swift exists)

### 3. GraphQL Client

**Complexity**: HIGH (query parsing, type generation)

```swift
@Query
func getUser(id: String) async throws -> User

@Mutation
func createUser(input: CreateUserInput) async throws -> User
```

- Query/mutation macros
- Automatic variable injection
- Error extraction from GraphQL response

**Current status**: In progress (GraphQLClient.swift exists)

### 4. Batch Operations

**Complexity**: MEDIUM (parallel execution coordination)

```swift
let results = try await client.batch {
    getUser(id: "1")
    getUser(id: "2")
    getUser(id: "3")
}
```

- Parallel request execution
- Configurable concurrency limits
- Partial failure handling

**Current status**: In progress (BatchOperations.swift exists)

### 5. Built-in Observability

**Complexity**: MEDIUM (OpenTelemetry integration)

- Distributed tracing (span propagation)
- Metrics (timing, success rates)
- Structured logging

**Current status**: DistributedTracing.swift exists, needs completion

### 6. Upload/Download Progress

**Complexity**: MEDIUM (URLSession delegate handling)

```swift
for try await progress in client.upload(data, to: "/files") {
    updateUI(progress.fractionCompleted)
}
```

- AsyncSequence for progress updates
- Resumable downloads
- Background transfer support

**Current status**: Not implemented

### 7. Circuit Breaker

**Complexity**: MEDIUM (state machine)

- Fail-fast after consecutive failures
- Half-open state for recovery testing
- Configurable thresholds

**Current status**: CircuitBreakerMiddleware exists

## Anti-Features

Things to deliberately NOT build:

### 1. Combine Integration

**Why avoid**: Combine is legacy for networking. Async/await supersedes it. Adding Combine creates maintenance burden without benefit.

### 2. URLSession Abstraction Layer

**Why avoid**: URLSession is already excellent. Wrapping it adds complexity without value. Use URLSession directly.

### 3. Alamofire-style Parameter Encoding

**Why avoid**: Codable + JSONEncoder handles this. No need for separate ParameterEncoding types.

### 4. Reactive Extensions (RxSwift)

**Why avoid**: Third-party reactive frameworks are obsolete with async/await. Technical debt to maintain.

### 5. Custom HTTP Parser

**Why avoid**: URLSession's HTTP handling is battle-tested. Don't reinvent.

## Feature Dependencies

```
                    ┌──────────────────┐
                    │  Sendable Types  │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
        ┌─────────┐    ┌─────────┐    ┌─────────────┐
        │ Actors  │    │ Async/  │    │ Interceptor │
        │         │    │ Await   │    │   Chain     │
        └────┬────┘    └────┬────┘    └──────┬──────┘
             │              │                │
             └──────────────┼────────────────┘
                            │
                 ┌──────────┴──────────┐
                 │                     │
                 ▼                     ▼
           ┌───────────┐         ┌───────────┐
           │ WebSocket │         │ GraphQL   │
           └───────────┘         └───────────┘
                 │                     │
                 └──────────┬──────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │ Observability │
                    └───────────────┘
```

## Comparison Matrix

| Feature | Current Codebase | Alamofire 5 | Moya | Get |
|---------|-----------------|-------------|------|-----|
| Async/await | Yes | Yes | Yes | Yes |
| Sendable | Partial | Yes | Partial | Yes |
| Result builders | Yes | No | No | Yes |
| Macros | Yes (partial) | No | No | No |
| WebSocket | In progress | No | No | No |
| GraphQL | In progress | No | No | No |
| Distributed tracing | In progress | No | No | No |
| Mock DSL | Yes | No | Yes | No |

**Key insight**: The existing codebase has features (macros, GraphQL, WebSocket) that competitors lack. Focus on completing and polishing these differentiators.

---
*Research date: 2026-02-14*
*Sources: Library documentation, GitHub repos, networking_modernization_analysis.md*
