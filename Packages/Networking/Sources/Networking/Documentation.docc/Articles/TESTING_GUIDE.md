# Testing Guide

Learn how to test networking code with the dedicated `NetworkingTesting` package and the
framework's supported fake seams.

## Testing Strategy

The framework intentionally keeps most production APIs concrete. Testing is built around narrow,
supported seams rather than protocolizing every value type.

Prefer this order of operations in user tests:

1. Use real value types like `HTTPRequest`, `HTTPResponse`, and `NetworkClient` configuration.
2. Add `NetworkingTesting` when you need a fake or mock seam.
3. Mock only approved runtime boundaries such as `HTTPClient`, auth providers, middleware, cache
   storage, time, tracing, and metrics.
4. Prefer middleware-oriented tests for new runtime behavior. Interceptor mocks remain available for
   compatibility scenarios only.

## Module Imports

For most app and package tests:

```swift
import Networking
import NetworkingTesting
```

For package-local tests inside the split modules, import only the package under test plus the test
helpers you need:

```swift
@testable import NetworkingRuntime
import NetworkingDSL
import NetworkingRuntimeDSL
import NetworkingTesting
```

## Supported Fake Seams

`NetworkingTesting` provides concrete test doubles for the approved seams:

- `MockNetworkClient` / `MockHTTPClient`
- `MockBearerTokenProvider`
- `MockCustomAuthProvider`
- `MockHTTPRequestMiddleware`
- `MockHTTPResponseMiddleware`
- `MockHTTPErrorMiddleware`
- `MockCacheStorage`
- `MockTimeProvider`
- `MockMetricsCollector`
- `MockTraceExporter`
- `MockURLProtocol`
- `SequentialMock`

All mock objects expose consistent verification helpers through `MockVerifiable`.

## Example: End-To-End Request Stubbing

```swift
import Testing
import Networking
import NetworkingTesting

@Test
func fetchProfile_usesMockURLProtocol() async throws {
  let contextID = UUID().uuidString
  let data = #"{"id": 42}"#.data(using: .utf8)!

  MockURLProtocol.clearAll(contextID: contextID)
  MockURLProtocol.stubSuccess(
    url: "https://api.example.com/profile",
    statusCode: 200,
    data: data,
    headers: ["Content-Type": "application/json"],
    contextID: contextID
  )

  let client = MockURLProtocol.createMockHTTPClient(contextID: contextID)
  let request = try HTTPRequest {
    GET("https://api.example.com/profile")
  }

  let response = try await client.execute(request)
  #expect(response.status == .ok)
}
```

## Example: Auth Provider Verification

```swift
import Testing
import Networking
import NetworkingTesting

@Test
func authentication_fetchesBearerToken() async throws {
  let tokenProvider = MockBearerTokenProvider()
  tokenProvider.stubToken("test-token")

  _ = try await tokenProvider.getCurrentToken()

  try tokenProvider.verifyTokenFetched(times: 1)
  try await tokenProvider.verifyCalledOnce()
}
```

## Example: Middleware Isolation

```swift
import Testing
import NetworkingRuntime
import NetworkingTesting

@Test
func requestMiddleware_addsHeader() async throws {
  let middleware = MockHTTPRequestMiddleware()
  middleware.stubAddHeader("X-Test", value: "true")

  let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
  let processed = try await middleware.modifyRequest(request)

  #expect(processed.headers["X-Test"] == "true")
  try await middleware.verifyCalledOnce()
}
```

## Verification Helpers

Verification remains async so the helpers stay Swift 6-safe:

```swift
try await mock.verifyCalledOnce()
try await mock.verifyCalledExactly(3)
try await mock.verifyCalledAtLeast(2)
try await mock.verifyNeverCalled()
```

Mock-specific helpers remain available where they add signal:

```swift
try mock.verifyTokenFetched(times: 1)
try await mockCache.verifySet("profile", times: 1)
try await mockTraceExporter.verifySpanExported(withName: "fetch_profile")
```

## Best Practices

- Use real request/response models first. Do not create mocks for builders or configuration values.
- Reset shared mocks between tests when you intentionally reuse them.
- Prefer actor-backed helpers like `MockCacheStorage` and `MockTraceExporter` for state-heavy tests.
- Keep interceptor-specific tests confined to `NetworkingInterceptorsCompat` compatibility scenarios.

## See Also

- <doc:Module-Migration>
- ``MockVerifiable``
- ``MockURLProtocol``
- ``MockNetworkClient``
