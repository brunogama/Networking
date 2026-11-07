# Testing Guide

Use Swift Testing with real request values and a test double at the boundary under test.
Add `NetworkingTesting` explicitly to your test target alongside `Networking`.

---

## Choose the boundary

Use `MockURLProtocol` with a real `NetworkClient` to exercise request preparation,
middleware order, response handling, and recovery. Give each parallel test a distinct
`MockContextIdentifier`; use it consistently for setup, session configuration, inspection,
and cleanup. This transport does not establish real DNS, TLS, or socket behavior.

Use `MockNetworkClient` when application code depends on `HTTPClient` and does not need
URLSession or the real middleware pipeline. It is an actor: await setup and inspection.
Register a complete expectation in one call before starting concurrent requests.

```swift
import Foundation
import Networking
import NetworkingTesting
import Testing

@Test func fulfillsClientExpectation() async throws {
  let client = MockNetworkClient()
  await client.expect(
    matching: .method(.get), .path("/profile"),
    response: .success(statusCode: 200, data: HTTPBody(Data(#"{"id":42}"#.utf8))),
    calls: .exactly(1)
  )
  let url = try #require(URL(string: "https://api.example.com/profile"))
  let response = try await client.execute(HTTPRequest(method: .get, url: url))
  #expect(response.status == .ok)
  try await client.verifyExpectations()
}
```

An optional `capture` closure observes matching requests after their call counts are
recorded. Each request uses the first matching response and records every matching
expectation. Reset clears this client's registrations and history without affecting
other clients or URLProtocol sessions.

---

## Available test doubles

The mutable test doubles own their state in actors:

- `MockNetworkClient` registers expectations and records request history.
- `MockBearerTokenProvider` configures access tokens and refresh results.
- `MockHTTPRequestMiddleware`, `MockHTTPResponseMiddleware`, and
  `MockHTTPErrorMiddleware` configure transformations or recovery and record calls.
- `MockCacheStorage` records cache operations and provides in-memory entries.
- `MockTraceExporter` captures spans or injects export failures.
- `MockMetricsCollector` captures request measurements.

`MockURLProtocol` remains a synchronized Foundation protocol subclass because URLSession
requires synchronous setup and lifecycle callbacks. Its asynchronous response task is
owned by the protocol instance and cancelled by `stopLoading`.

---

## Verify authentication and middleware

```swift
@Test func recordsTokenAccess() async throws {
  let provider = MockBearerTokenProvider()
  await provider.stubToken("test-token")
  _ = try await provider.getCurrentToken()
  try await provider.verifyTokenFetched(times: 1)
  try await provider.verifyCalledOnce()
}

@Test func preservesRequestIdentity() async throws {
  let middleware = MockHTTPRequestMiddleware()
  await middleware.stubAddHeader("X-Test", value: "true")
  let url = try #require(URL(string: "https://example.com"))
  let request = HTTPRequest(method: .get, url: url)
  let processed = try await middleware.modifyRequest(request)
  #expect(processed.id == request.id)
  #expect(processed.headers["X-Test"] == "true")
  try await middleware.verifyCalledOnce()
}
```

The token, middleware, cache, tracing, and metrics mocks conform to `MockVerifiable`.
Use `verifyCalledOnce`, `verifyCalledExactly`, `verifyCalledAtLeast`, or `verifyNeverCalled`.
`MockNetworkClient` verifies its individual expectations with `verifyExpectations`.
All actor inspection and verification requires `await`.

---

## Control asynchronous interleavings

Keep test state local. For actor reentrancy and cancellation, use an explicit arrival
signal and controlled suspension point, perform the competing operation, then release
and await the work. A sleep alone does not establish that an interleaving occurred.
Await all child work before checking final state or discarding a mock.

Middleware mocks select their configured transformation before suspending. Reset clears
recorded calls without restoring them when an already selected operation resumes.
A mock client captures its response before a delay, and cancellation ends that delay.
Use a controlled client or native transport regression test for task lifetime guarantees.

Use a shared configured `JSONCodec` for JSON stubs when the consumer uses custom date or
key conversion. Avoid live credentials and external services in tests.
