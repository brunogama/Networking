# Testing Patterns

**Analysis Date:** 2026-02-14

## Test Framework

**Runner:**
- Primary: Swift Testing (native, modern, no external dependency)
- Legacy: XCTest (some tests still use XCTest base classes)
- Property-based: SwiftCheck 0.12.0+
- BDD Ready: Quick 7.4.0+, Nimble 13.0.0+ (integrated, not fully used)
- Macro testing: MacroTesting 0.5.2+

**Config:**
- Package.swift target: `NetworkingTests`
- Run: `swift test` or `swift test NetworkingTests`
- Test discovery: Automatic (test files must match pattern: `*Tests.swift` or `*Test.swift`)

**Run Commands:**
```bash
swift test                           # Run all tests
swift test --filter InterceptorTests # Run specific test class/filter
swift test --verbose                # Show test names and timing
swift test --parallel               # Run in parallel (default)
swift test --disable-parallel       # Run sequentially (debugging)
swift test --code-coverage          # Generate coverage report
```

## Test File Organization

**Location:**
- Primary: `Tests/NetworkingTests/` directory
- Organized by component: `Interceptors/`, `Macros/`, `PropertyTests/` subdirectories
- 62+ test files covering all public APIs

**Naming:**
- Pattern: `ComponentTests.swift` or `FeatureNameTests.swift`
- Convention: One major test suite per file
- Example files: `CachingTests.swift`, `IntegrationTests.swift`, `MockingTests.swift`

**Structure - Modern (Swift Testing):**
```swift
import Testing
import Foundation
@testable import Networking

@Suite("Feature Description")
struct ComponentTests {
  // Test methods using @Test attribute
}
```

**Structure - Legacy (XCTest):**
```swift
import XCTest
@testable import Networking

final class ComponentTests: XCTestCase {
  // Test methods using testXXX() naming
}
```

## Test Structure

**Suite Organization (Swift Testing Pattern):**
```swift
@Suite("Caching System Tests")
struct CachingTests {
  // MARK: - Test Data Setup

  private func createTestRequest(url: String = "https://api.example.com/test") throws -> HTTPRequest {
    try HTTPRequest {
      GET(url)
      Header("Authorization", "Bearer test-token")
    }
  }

  // MARK: - Basic Cache Entry Tests

  @Test("Cache entry creation and expiration")
  func testCacheEntryBasics() async throws {
    let response = createTestResponse()
    let entry = CachingMiddleware.CacheEntry(response: response, ttl: 300.0)

    #expect(entry.response.status == .ok)
    #expect(!entry.isExpired)
  }
}
```

**Patterns:**
- Test helper methods prefixed `private func` (not tests)
- Helper factories for test data: `createTestRequest()`, `createTestResponse()`
- Isolated test setup (no global state)
- Test names use simple `@Test("description")` attribute
- Test methods are `async` (supports async/await network calls)

## Test Types

### Unit Tests

**Purpose:** Verify components in isolation with mocks

**Location:** Component-specific files (e.g., `CachingTests.swift`, `ErrorHandlingTests.swift`)

**Pattern:**
```swift
@Test("Caching middleware basic functionality")
func testCachingMiddlewareBasic() async throws {
  // Arrange: Set up component and mocks
  let cache = MemoryCacheStorage(maxSize: 10)
  let key = "test-key"
  let response = createTestResponse()
  let entry = CachingMiddleware.CacheEntry(response: response, ttl: 300.0)

  // Act: Execute behavior
  await cache.set(key, entry: entry)
  let retrieved = await cache.get(key)

  // Assert: Verify results
  #expect(retrieved != nil)
  #expect(retrieved?.response.status == .ok)
}
```

**Coverage:** Public methods, business logic, error conditions

### Property-Based Tests (SwiftCheck)

**Purpose:** Verify properties hold across generated inputs

**Location:** `Tests/NetworkingTests/PropertyTests/` subdirectory

**Framework:** SwiftCheck (Haskell-inspired property testing for Swift)

**Files:**
- `RetryBackoffPropertyTests.swift` - Exponential backoff monotonicity, bounds
- `CircuitBreakerFSMPropertyTests.swift` - Finite state machine properties
- `InterceptorChainMonoidTests.swift` - Chain composition properties
- `HeaderSecurityPropertyTests.swift` - Header validation consistency

**Pattern (XCTest-based, SwiftCheck generator):**
```swift
final class RetryBackoffPropertyTests: XCTestCase {
  func testDelayIsNonNegative() {
    property("Delay is always non-negative")
      <- forAll(RetryConfigGen.arbitrary, Gen.choose((0, 20))) {
        (config: RetryConfig, attemptCount: Int) in
        let delay = Self.calculateDelay(attemptCount: attemptCount, ...)
        return delay >= 0
      }
  }

  func testDelayMonotonicity() {
    property("Delay is monotonically increasing") <- forAll(RetryConfigGen.arbitrary) { config in
      var previousDelay = 0.0
      for attempt in 0..<20 {
        let exponentialDelay = config.baseDelay * pow(2.0, Double(attempt))
        let delay = min(exponentialDelay, config.maxDelay)
        if delay < previousDelay { return false }
        previousDelay = delay
      }
      return true
    }
  }
}
```

**When to Write:**
- Retry/backoff calculations (exponential growth properties)
- Interceptor chain composition (order invariants)
- Cache eviction logic (LRU/FIFO properties)
- Timeout edge cases (monotonic behavior)

**Generator Pattern:**
```swift
extension RetryConfigGen {
  static var arbitrary: Gen<RetryConfig> {
    Gen.zip(
      Gen.choose((0.1, 10.0)),  // baseDelay
      Gen.choose((0.5, 60.0))   // maxDelay
    ).map { baseDelay, maxDelay in
      RetryConfig(baseDelay: baseDelay, maxDelay: max(baseDelay, maxDelay))
    }
  }
}
```

### Integration Tests

**Purpose:** Verify components work together end-to-end

**Location:** `Tests/NetworkingTests/IntegrationTests.swift`

**Framework:** Uses MockURLProtocol for URLSession-level simulation

**Pattern:**
```swift
@Test("NetworkClient with MockURLProtocol handles redirects")
func testNetworkClientWithMockProtocolHandlesRedirects() async throws {
  // Setup: Configure URLSession with MockURLProtocol
  let configuration = URLSessionConfiguration.ephemeral
  configuration.protocolClasses = [MockURLProtocol.self]
  let session = URLSession(configuration: configuration)

  let client = NetworkClient(session: session)

  // Stub: Register mock responses at protocol level
  MockURLProtocol.stub(
    url: URL(string: "https://example.com/old")!,
    response: URLResponse(...),
    statusCode: 301  // Redirect
  )
  MockURLProtocol.stub(
    url: URL(string: "https://example.com/new")!,
    response: URLResponse(...),
    statusCode: 200
  )

  // Execute: Make request through real URLSession stack
  let request = try HTTPRequest { GET("https://example.com/old") }
  let response = try await client.execute(request)

  // Verify: Check end-to-end behavior
  #expect(response.status == .ok)
}
```

### Macro Expansion Tests

**Purpose:** Verify Swift macros expand to correct code

**Location:** `Tests/NetworkingTests/Macros/` subdirectory

**Framework:** MacroTesting (snapshot testing of macro expansion)

**Files:**
- `APIMacroTests.swift` - @API macro
- `GETMacroTests.swift` - @GET macro
- `POSTMacroTests.swift` - @POST macro
- `PUTMacroTests.swift` - @PUT macro
- `DELETEMacroTests.swift` - @DELETE macro
- `BodyMacroTests.swift` - @Body macro
- `ConfigurationMacroTests.swift` - Configuration macros
- `InterceptorMacroTests.swift` - Interceptor integration

**Pattern (snapshot-based assertion):**
```swift
import MacroTesting

@Test
func apiMacro_generatesClientType() {
  assertMacro {
    """
    @API(baseURL: "https://api.example.com")
    protocol UserAPI {
      @GET("/users/{id}")
      func getUser(@Path id: String) async throws -> User
    }
    """
  } expansion: {
    """
    extension UserAPI {
      func getUser(id: String) async throws -> User {
        // Generated implementation
      }
    }
    """
  }
}
```

## Mocking

### MockNetworkClient (Unit Testing)

**Purpose:** Rapid unit test execution without HTTP layer

**Location:** `Sources/Networking/Testing/MockNetworkClient.swift` (726 lines)

**Pattern:**
```swift
@Test("Feature calls NetworkClient correctly")
func testFeatureCallsNetworkClient() async throws {
  // Setup mock
  let mockClient = MockNetworkClient()

  // Stub response
  mockClient.stub(
    request: HTTPRequest(method: .get, url: URL(string: "https://api.example.com/users")!),
    response: HTTPResponse(
      status: .ok,
      body: Data(#"[{"id": 1, "name": "John"}]"#.utf8)
    )
  )

  // Execute feature (passes mock to business logic)
  let users = try await fetchUsers(client: mockClient)

  // Assert behavior
  #expect(users.count == 1)
  #expect(users[0].name == "John")
}
```

**Features:**
- Expectation-based API with method chaining
- Matcher patterns: `.path()`, `.method()`, `.custom()`
- Call count expectations: `.once()`, `.atLeastOnce()`, `.exactly(n)`, etc.
- Response stubbing: `.andReturn()`, `.andReturnJSON()`, `.andReturnError()`
- Request capture and verification
- CallCountExpectation enum for flexible matching

**Advantages:**
- Fast (no network, no URLSession overhead)
- Simple to stub and verify
- Good for business logic testing

**Limitations:**
- Doesn't test URLSession integration
- Can't verify HTTP headers, encoding
- Protocol-level behaviors not tested

### MockURLProtocol (Integration Testing)

**Purpose:** Test URLSession-level behavior with realistic HTTP layer

**Location:** `Sources/Networking/Testing/MockURLProtocol.swift` (633 lines)

**Pattern:**
```swift
@Test("NetworkClient validates HTTPS requirement")
func testNetworkClientValidatesHTTPS() async throws {
  // Setup: Configure session with mock protocol
  let configuration = URLSessionConfiguration.ephemeral
  configuration.protocolClasses = [MockURLProtocol.self]
  let session = URLSession(configuration: configuration)

  let client = NetworkClient(session: session)

  // Stub: Register HTTP (insecure) response
  MockURLProtocol.stubSuccess(
    url: "http://insecure.example.com",
    statusCode: 200,
    data: Data()
  )

  // Execute & Verify: Expect security rejection
  do {
    _ = try await client.execute(
      HTTPRequest(method: .get, url: URL(string: "http://insecure.example.com")!)
    )
    #expect(Bool(false), "Should reject HTTP")
  } catch HTTPError.securityViolation {
    // Expected: HTTP rejected
  }
}
```

**Features:**
- URLProtocol subclass intercepts URLSession requests
- Stub methods: `.stubSuccess()`, `.stubJSON()`, `.stubError()`, `.clearAll()`
- Request capture: `.expectRequest()`, `.capturedRequests`
- Response lifecycle hooks: `didLoad`, `didFinish`, `didFail`
- Header validation and inspection

**Advantages:**
- Tests actual URLSession behavior
- Can verify headers, redirects, authentication
- More realistic than MockNetworkClient
- Tests protocol-level concerns

**Limitations:**
- Slower than MockNetworkClient
- More complex setup
- Requires URLProtocol knowledge

### MockDSL

**Purpose:** Builder pattern for test fixture construction

**Location:** `Sources/Networking/Testing/MockDSL.swift`

**Pattern:**
```swift
@Test("Using MockDSL for fixture construction")
func testWithMockDSL() async throws {
  let mock = try NetworkingMock {
    Expect {
      Method(.get)
      Path("/users/123")
      HeaderPresent("Authorization")
    }
    Respond {
      Status(.ok)
      JSONBody(User(id: 123, name: "Test"))
    }
  }

  let client = mock.client
  let response = try await client.execute(request)

  #expect(response.status == .ok)
}
```

**Features:**
- Result builder syntax for readable test setup
- Declarative expectation matching
- Response configuration DSL
- Reduces boilerplate in test files

## Test Organization Best Practices

**✅ DO:**
- Test public behavior (API contract)
- Use descriptive names: `testCachingMiddlewareStoresSuccessfulResponse()`
- Organize by component (one file per major component)
- Test error paths (timeouts, invalid responses, network failures)
- Use meaningful assertions with failure context: `#expect(value == expected, "reason")`
- Mock external dependencies (network, filesystem)
- Run tests in parallel (default behavior)
- Extract test helpers and factories

**❌ DON'T:**
- Test implementation details (private methods)
- Use `skip()` without documenting why (add TODO)
- Use `sleep()` in async tests (async/await or expectations instead)
- Hard-code test data (use factories: `createTestResponse()`)
- Test third-party code (only your integration)
- Leave commented-out tests (delete or fix)
- Create test order dependencies
- Share state between tests

## Fixtures and Factories

**HTTPRequest Factory Pattern:**
```swift
private func createTestRequest(
  url: String = "https://api.example.com/test",
  method: HTTPMethod = .get
) throws -> HTTPRequest {
  try HTTPRequest {
    if method == .get { GET(url) }
    else if method == .post { POST(url) }
    Header("Authorization", "Bearer test-token")
  }
}
```

**HTTPResponse Factory Pattern:**
```swift
private func createTestResponse(
  status: HTTPStatus = .ok,
  headers: [String: String] = [:],
  body: String = "test response body"
) -> HTTPResponse {
  let request = HTTPRequest(method: .get, url: URL(string: "https://api.example.com/test")!)
  return HTTPResponse(
    request: request,
    status: status,
    headers: headers,
    body: body.data(using: .utf8)
  )
}
```

**Location:** Defined at top of test file or extracted to shared extension

## Coverage

**Requirements:**
- New public APIs: Target >95% line coverage
- Core middleware: 100% coverage expected
- Error paths: Always tested

**View Coverage:**
```bash
swift test --code-coverage
# Generated coverage report location depends on CI/CD setup
```

**Test Coverage Targets:**
| Component | Unit | Property | Integration | Target |
|-----------|------|----------|-------------|--------|
| Interceptors | ✅ | ✅ | ✅ | 100% |
| Middleware | ✅ | — | ✅ | 100% |
| Macros | ✅ | — | — | 100% |
| NetworkClient | ✅ | — | ✅ | 95%+ |
| Error Handling | ✅ | ✅ | — | 100% |
| Caching | ✅ | — | ✅ | 100% |

## Test Writing Patterns

### Pattern 1: Unit Test (Arrange-Act-Assert)

```swift
@Test("Component behavior condition")
func testComponentBehavior() async throws {
  // Arrange: Create component and inputs
  let cache = ResponseCache()
  let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
  let expectedResponse = HTTPResponse(status: .ok, body: Data())

  // Act: Execute behavior
  cache.cache(expectedResponse, for: request.url)
  let cachedResponse = cache.getCached(for: request.url)

  // Assert: Verify results
  #expect(cachedResponse?.status == .ok)
}
```

### Pattern 2: Error Path Testing

```swift
@Test("Timeout handling")
func testTimeoutHandling() async throws {
  let interceptor = TimeoutInterceptor(timeout: 0.001)

  do {
    _ = try await interceptor.process(request, context: context)
    #expect(Bool(false), "Should timeout")
  } catch HTTPError.timeout {
    // Expected: timeout error thrown
  }
}
```

### Pattern 3: Property-Based Test

```swift
func testRetryDelayMonotonicity() {
  property("Delay increases monotonically") <- forAll(retryGen) { config in
    var previousDelay = 0.0
    for attempt in 0..<10 {
      let delay = calculateDelay(attempt: attempt, config: config)
      if delay < previousDelay { return false }
      previousDelay = delay
    }
    return true
  }
}
```

### Pattern 4: Mock Verification

```swift
@Test("Client sets authorization header")
func testAuthorizationHeader() async throws {
  let mockClient = MockNetworkClient()
  mockClient.expectCall { request in
    #expect(request.headers["Authorization"] != nil)
  }

  let request = HTTPRequest(method: .get, url: URL(string: "https://api.example.com/users")!)
    .withHeader("Authorization", "Bearer token123")

  _ = try await mockClient.execute(request)
  mockClient.verifyExpectations()
}
```

### Pattern 5: Async Test with Task.sleep()

```swift
@Test("Cache entry expiration")
func testCacheEntryExpiration() async throws {
  let entry = CachingMiddleware.CacheEntry(
    response: testResponse,
    ttl: 0.05  // 50ms
  )

  // Wait for expiration with sufficient margin
  try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

  #expect(entry.isExpired)
}
```

## Running Tests

**Common Commands:**
```bash
swift test                                    # All tests
swift test --filter InterceptorChainTests    # Specific test class
swift test --filter "Caching"                # Tests matching pattern
swift test --verbose                         # Show each test
swift test --parallel                        # Parallel (default)
swift test --disable-parallel                # Single-threaded (debugging)
swift test NetworkingTests --filter GETMacro # Specific file and filter
```

**Coverage:**
```bash
swift test --code-coverage
# Check CI/CD for coverage report generation
```

## Pre-Commit Test Checklist

**Before committing, verify:**
- [ ] All tests pass: `swift test`
- [ ] No skipped tests: `grep -r "@Test.*skip" Tests/`
- [ ] Coverage maintained: New code has unit + integration tests
- [ ] No hardcoded test data: Use factories instead
- [ ] Mock setup is clear: Easy to understand test data
- [ ] Error paths tested: Try/catch blocks have test coverage
- [ ] Property tests cover algorithms: Backoff, cache eviction, etc.
- [ ] Integration tests verify end-to-end: MockURLProtocol used appropriately

## Test Helpers & Utilities

**Testing Module:** `Networking.Testing` public target
- `MockNetworkClient` - Expectation-based HTTP mocking
- `MockURLProtocol` - URLSession-level protocol mocking
- `MockDSL` - Builder pattern for fixture construction
- `HTTPRequest` + `HTTPResponse` test extensions (factories)

**No Global Test State:** Each test is independent (no shared setUp/tearDown globals)

**Helper Location:** Test-specific helpers defined in test files, shared helpers in extensions

## Known Test Patterns

**Timeout Testing:**
- Use very short timeouts (0.001 seconds)
- Catch `HTTPError.timeout` specifically
- Don't use `sleep()` - use async/await properly

**Retry Testing:**
- Mock multiple responses (fail → succeed)
- Verify attempt count increments
- Test exponential backoff timing

**Cache Testing:**
- Create entries with TTL
- Wait with `Task.sleep(nanoseconds:)`
- Verify expiration behavior
- Test LRU eviction under size limits

**Header Testing:**
- Stub requests with specific headers
- Capture and inspect headers in mock
- Verify security headers present

## Test Organization by Component

| Component | Test Location | Type | Pattern |
|-----------|---------------|------|---------|
| NetworkClient | `IntegrationTests.swift` | Integration | MockURLProtocol |
| Interceptors | `Interceptors/*Tests.swift` | Unit + Property | MockNetworkClient + SwiftCheck |
| Middleware | `CachingTests.swift`, etc | Unit + Integration | MockNetworkClient + MockURLProtocol |
| Macros | `Macros/*Tests.swift` | Expansion | MacroTesting snapshot |
| Error handling | `IntegrationTests.swift` | Unit + Property | SwiftCheck generators |
| Authentication | `Interceptors/AuthenticationInterceptorTests.swift` | Unit | MockNetworkClient |

---

*Testing analysis: 2026-02-14*
