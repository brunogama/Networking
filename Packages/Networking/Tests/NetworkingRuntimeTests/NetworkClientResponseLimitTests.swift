import Foundation
import NetworkingCore
import NetworkingRuntime
import NetworkingTesting
import Testing

@Suite("NetworkClient response size limit")
struct NetworkClientResponseLimitTests {
  @Test("A response at the limit is returned")
  func acceptsResponseAtLimit() async throws {
    let (client, request) = try makeClient(body: "abc", limit: 3)
    let response = try await client.execute(request)
    #expect(response.body == HTTPBody(Data("abc".utf8)))
  }

  @Test("A zero-byte limit accepts an empty response")
  func acceptsEmptyResponse() async throws {
    let (client, request) = try makeClient(body: "", limit: 0)
    let response = try await client.execute(request)
    #expect(response.body == HTTPBody(Data()))
  }

  @Test("A negative limit is rejected")
  func rejectsNegativeLimit() async throws {
    let (client, request) = try makeClient(body: "", limit: -1)
    await #expect(throws: HTTPError.self) {
      try await client.execute(request)
    }
  }

  @Test("A response exceeding the limit fails")
  func rejectsOversizedResponse() async throws {
    let (client, request) = try makeClient(body: "abcd", limit: 3)
    do {
      _ = try await client.execute(request)
      Issue.record("An oversized response was returned")
    } catch {
      guard case .configuration = error.category else {
        Issue.record("Expected a response limit error, got \(error.category)")
        return
      }
    }
  }

  @Test("Response middleware cannot return a body over the limit")
  func rejectsOversizedMiddlewareResponse() async throws {
    let middleware = MockHTTPResponseMiddleware()
    await middleware.stubReplaceBody(HTTPBody(Data("abcd".utf8)))
    let (client, request) = try makeClient(body: "a", limit: 3, middleware: middleware)
    await #expect(throws: HTTPError.self) {
      try await client.execute(request)
    }
  }

  private func makeClient(
    body: String,
    limit: Int,
    middleware: MockHTTPResponseMiddleware? = nil
  ) throws -> (NetworkClient, HTTPRequest) {
    let context = MockContextIdentifier()
    let url = HTTPRequestURL(try #require(URL(string: "https://example.test/limit")))
    MockURLProtocol.stubSequential(
      url: url,
      responses: [.success(statusCode: 200, data: HTTPBody(Data(body.utf8)))],
      contextID: context
    )
    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: context)
    )
    return (
      NetworkClient(
        session: session,
        responseMiddlewares: middleware.map { [$0] } ?? [],
        maximumResponseBytes: limit
      ),
      HTTPRequest(method: .get, url: url)
    )
  }
}
