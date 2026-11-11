import Foundation
import Testing

@testable import NetworkingTesting
import NetworkingCore
@Suite("Mock Middleware Tests")
struct MockMiddlewareTests {
  // MARK: - MockHTTPRequestMiddleware Tests

  @Test("MockHTTPRequestMiddleware applies transform when stubbed")
  func transformsRequests() async throws {
    let mock = MockHTTPRequestMiddleware()
    await mock.stubAddHeader("X-Custom", value: "test-value")

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users")!
    )

    let processed = try await mock.modifyRequest(request)

    #expect(processed.headers["X-Custom"] == "test-value")
    #expect(processed.id == request.id)
  }

  @Test("MockHTTPRequestMiddleware passes through when no stub")
  func passesRequestsThrough() async throws {
    let mock = MockHTTPRequestMiddleware()

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users")!
    )

    let processed = try await mock.modifyRequest(request)

    #expect(processed.url == request.url)
    #expect(processed.method == request.method)
  }

  @Test("MockHTTPRequestMiddleware throws when stub failure")
  func throwsConfiguredRequestFailure() async {
    let mock = MockHTTPRequestMiddleware()
    await mock.stubFailure(URLError(.badURL))

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com")!
    )

    await #expect(throws: URLError.self) {
      _ = try await mock.modifyRequest(request)
    }
  }

  @Test("MockHTTPRequestMiddleware captures all requests")
  func capturesRequests() async throws {
    let mock = MockHTTPRequestMiddleware()

    let request1 = HTTPRequest(method: .get, url: URL(string: "https://example.com/1")!)
    let request2 = HTTPRequest(method: .post, url: URL(string: "https://example.com/2")!)

    _ = try await mock.modifyRequest(request1)
    _ = try await mock.modifyRequest(request2)

    let captured = await mock.getCapturedRequests()
    #expect(captured.count == 2)
    #expect(captured[0].url.rawValue.path == "/1")
    #expect(captured[1].url.rawValue.path == "/2")
  }

  // MARK: - MockHTTPResponseMiddleware Tests

  @Test("MockHTTPResponseMiddleware applies transform when stubbed")
  func transformsResponses() async throws {
    let mock = MockHTTPResponseMiddleware()
    let newBody = HTTPBody(Data("transformed".utf8))
    await mock.stubReplaceBody(newBody)

    let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
    let response = HTTPResponse(
      request: request,
      status: .ok,
      body: HTTPBody(Data("original".utf8))
    )

    let processed = try await mock.processResponse(response, for: request)
    #expect(processed.body == newBody)
  }

  @Test("MockHTTPResponseMiddleware passes through when no stub")
  func passesResponsesThrough() async throws {
    let mock = MockHTTPResponseMiddleware()

    let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
    let response = HTTPResponse(request: request, status: .ok, body: HTTPBody(Data("data".utf8)))

    let processed = try await mock.processResponse(response, for: request)

    #expect(processed.body == response.body)
  }

  @Test("MockHTTPResponseMiddleware captures all responses")
  func capturesResponses() async throws {
    let mock = MockHTTPResponseMiddleware()

    let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
    let response1 = HTTPResponse(request: request, status: .ok, body: nil as HTTPBody?)
    let response2 = HTTPResponse(request: request, status: .created, body: nil as HTTPBody?)

    _ = try await mock.processResponse(response1, for: request)
    _ = try await mock.processResponse(response2, for: request)

    let captured = await mock.getCapturedResponses()
    #expect(captured.count == 2)
    #expect(captured[0].response.status == .ok)
    #expect(captured[1].response.status == .created)
  }

  // MARK: - MockHTTPErrorMiddleware Tests

  @Test("MockHTTPErrorMiddleware tracks call count")
  func errorMiddleware_tracksCallCount() async throws {
    let mock = MockHTTPErrorMiddleware()
    await mock.stubSwallow()

    let count = await mock.callCount
    #expect(count == 0)
  }
}
