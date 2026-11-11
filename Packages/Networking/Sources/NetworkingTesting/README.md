# NetworkingTesting

Add `NetworkingTesting` as an explicit dependency of your test target. Import it
alongside `Networking` and Swift Testing. The product is not automatically added
by debug compilation or by importing the umbrella library.

---

## Exercise the real client with an isolated transport

Use `MockURLProtocol` when testing request preparation, middleware ordering, or
response handling through `NetworkClient`. Give every parallel test a distinct
`MockContextIdentifier` and use it for registration, configuration, inspection,
and cleanup.

```swift
import Foundation
import Networking
import NetworkingTesting
import Testing

@Test func returnsStubbedResponse() async throws {
  let context = MockContextIdentifier()
  let url = HTTPRequestURL(try #require(URL(string: "https://api.example.com/users")))
  defer { MockURLProtocol.clearAll(contextID: context) }
  MockURLProtocol.stub(
    matching: .url(url),
    response: .success(statusCode: 200, data: HTTPBody(Data("[]".utf8))),
    contextID: context
  )
  let session = URLSession(
    configuration: MockURLProtocol.createMockConfiguration(contextID: context)
  )
  defer { session.invalidateAndCancel() }
  let client = NetworkClient(session: session)
  let response = try await client.execute(HTTPRequest(method: .get, url: url))
  #expect(response.status == .ok)
  #expect(response.body == HTTPBody(Data("[]".utf8)))
  #expect(await MockURLProtocol.getRequestCount(for: url, contextID: context) == 1)
}
```

`stubSequential(url:responses:contextID:)` supplies successive responses, such as
a 401 followed by a successful refresh retry. `getCapturedRequests(contextID:)`
returns the intercepted requests for assertions. URLProtocol stubs exercise
client behavior but do not establish real DNS, TLS, connection reuse, or socket
cancellation behavior.

---

## Substitute a client for application tests

Use `MockNetworkClient` for code that depends on `HTTPClient` and does not need
to exercise URLSession or the real middleware pipeline.

```swift
@Test func fulfillsClientExpectation() async throws {
  let client = MockNetworkClient()
  await client.expect(
    matching: .method(.get), .path("/users"),
    response: .success(statusCode: 200, data: HTTPBody(Data("[]".utf8))),
    calls: .exactly(1)
  )
  let url = try #require(URL(string: "https://api.example.com/users"))
  let response = try await client.execute(HTTPRequest(method: .get, url: url))
  #expect(response.status == .ok)
  try await client.verifyExpectations()
}
```

Registration, request recording, and verification belong to the mock actor. Each
`expect` call installs its matching rules, response, call count, and optional
capture closure atomically. Configure expectations before starting concurrent
work, await that work, then verify and discard the mock. A reset clears only that
client's expectations and history. Already selected responses retain their
configuration and respect cancellation during a delay.

`stubGET` and `stubPOST` are async setup conveniences. Pass a `JSONCodec` into the
client initializer when JSON stubs need the same date or key conventions as the
code under test. An expectation verifies requests and call counts; use the real
client with isolated transport to exercise its middleware pipeline.

---

## Test asynchronous behavior deliberately

Use Swift Testing's `@Test`, `#expect`, and `#require`. Keep test state local and
avoid global cleanup that can remove another parallel test's stubs. For
cancellation and actor reentrancy, use a controlled suspension point and an
explicit arrival signal, force the relevant interleaving, and await completion.
A configured delay or sleep alone is not evidence that a race was exercised.

Do not use live credentials or external services. Test middleware through a real
`NetworkClient` plus isolated transport when its ordering or recovery is the
behavior under test. Use a purpose-built controlled client for task-lifetime
assertions; the general URLProtocol mock is not a substitute for cancellation
verification at the native transport boundary.
