# Testing Guide

Learn how to test your networking code using the Networking framework's built-in testing utilities and mock implementations.

## Protocol Mocking for User Tests

The Networking framework provides comprehensive mock implementations for all major protocols, making it easy to test your networking code without making real HTTP requests.

All mocks conform to `MockVerifiable` for consistent verification patterns.

### Available Mocks

The framework provides the following mock implementations:

- **MockHTTPClient** (alias for MockNetworkClient) - Mock HTTP client for unit testing
- **MockBearerTokenProvider** - Mock bearer token authentication provider
- **MockCustomAuthProvider** - Mock custom authentication provider
- **MockHTTPRequestMiddleware** - Mock request transformation middleware
- **MockHTTPResponseMiddleware** - Mock response transformation middleware
- **MockHTTPErrorMiddleware** - Mock error handling middleware
- **MockRequestInterceptor** - Mock request interceptor
- **MockResponseInterceptor** - Mock response interceptor
- **MockCacheStorage** - Mock cache storage (actor-based)
- **MockTimeProvider** - Mock time provider for testing time-dependent code
- **MockMetricsCollector** - Mock metrics collector (actor-based)
- **MockTraceExporter** - Mock trace exporter (actor-based)

### Usage Examples

#### Example 1: Testing with Mock Token Provider

```swift
import Testing
@testable import Networking

@Test
func userService_fetchesProfile_withValidToken() async throws {
  let mockTokenProvider = MockBearerTokenProvider()
  mockTokenProvider.stubToken("test-token-123")

  let client = NetworkClient {
    BaseURL("https://api.example.com")
    BearerAuth(provider: mockTokenProvider)
  }

  let request = HTTPRequest { GET("/profile") }
  let response = try await client.execute(request)

  #expect(response.status == .ok)
  try await mockTokenProvider.verifyCalledOnce()
}
```

#### Example 2: Testing Custom Middleware

```swift
@Test
func middleware_addsCustomHeader() async throws {
  let mockMiddleware = MockHTTPRequestMiddleware()
  mockMiddleware.stubAddHeader("X-Custom", value: "test-value")

  let request = HTTPRequest { GET("/users") }
  let processed = try await mockMiddleware.modifyRequest(request)

  #expect(processed.headers["X-Custom"] == "test-value")
  try await mockMiddleware.verifyCalledOnce()
}
```

#### Example 3: Testing Cache Behavior

```swift
@Test
func caching_storesResponse() async throws {
  let mockCache = MockCacheStorage()
  let entry = CachingMiddleware.CacheEntry(
    response: HTTPResponse(...),
    ttl: 300
  )

  await mockCache.set("cache-key", entry: entry)

  try await mockCache.verifySet("cache-key", times: 1)
}
```

### Verification Patterns

All mocks conforming to `MockVerifiable` provide standard verification methods:

#### Async Verification Methods

Due to Swift 6 concurrency requirements, all verification methods are async:

```swift
// Verify called exactly once
try await mock.verifyCalledOnce()

// Verify called exact number of times
try await mock.verifyCalledExactly(3)

// Verify never called
try await mock.verifyNeverCalled()

// Verify called at least N times
try await mock.verifyCalledAtLeast(2)
```

#### Mock-Specific Verification

Some mocks provide additional verification methods:

```swift
// MockBearerTokenProvider
try mock.verifyTokenFetched(times: 1)
try mock.verifyRefreshed(times: 2)
try await mock.verifyNeverAccessed()

// MockCacheStorage
try await mockCache.verifyGet("key", times: 1)
try await mockCache.verifySet("key", times: 1)

// MockTraceExporter
try await mockTracer.verifySpanExported(withName: "operation")
```

### Best Practices

#### 1. Use Actors for State-Heavy Mocks

Actor-based mocks (`MockCacheStorage`, `MockMetricsCollector`, `MockTraceExporter`) provide built-in thread safety:

```swift
let mockCache = MockCacheStorage() // Actor - thread-safe by design
await mockCache.set("key", entry: entry)
let retrieved = await mockCache.get("key")
```

#### 2. Use DispatchQueue for Simple Mocks

Class-based mocks use DispatchQueue for synchronization:

```swift
let mockProvider = MockBearerTokenProvider() // Thread-safe via DispatchQueue
mockProvider.stubToken("token")
_ = try await mockProvider.getCurrentToken()
```

#### 3. Always Verify Expectations

Verify that mocks were called as expected to catch missing calls:

```swift
@Test
func feature_callsTokenProvider() async throws {
  let mock = MockBearerTokenProvider()
  mock.stubToken("token")

  // ... execute code that should call the mock ...

  try await mock.verifyCalledOnce() // Verify it was actually called
}
```

#### 4. Reset Mocks Between Tests

If reusing mocks, reset them between tests:

```swift
let mock = MockBearerTokenProvider()

// First test
mock.stubToken("token1")
// ... test code ...

// Reset before second test
mock.reset()
mock.stubToken("token2")
// ... test code ...
```

### Testing Error Paths

Mocks support error stubbing for testing error handling:

```swift
@Test
func client_handlesTokenFetchError() async throws {
  let mock = MockBearerTokenProvider()
  mock.stubTokenFetchError(URLError(.notConnectedToInternet))

  await #expect(throws: URLError.self) {
    _ = try await mock.getCurrentToken()
  }
}
```

### Testing Time-Dependent Code

Use `MockTimeProvider` for testing time-dependent logic:

```swift
@Test
func cache_expiresAfterTTL() async throws {
  let mockTime = MockTimeProvider()
  mockTime.setTime(Date(timeIntervalSince1970: 1000))

  // ... set up cache with TTL ...

  mockTime.advance(by: 400) // Advance past TTL

  // ... verify cache entry expired ...
}
```

## See Also

- ``MockVerifiable`` - Protocol for verifiable mock objects
- ``MockBearerTokenProvider`` - Mock bearer token provider
- ``MockHTTPRequestMiddleware`` - Mock request middleware
- ``MockCacheStorage`` - Mock cache storage
