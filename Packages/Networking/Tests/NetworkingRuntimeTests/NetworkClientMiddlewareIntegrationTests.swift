import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite("NetworkClient middleware integration")
struct NetworkClientMiddlewareIntegrationTests {
  @Test("A 401 refreshes authentication and retries with the new token")
  func refreshesAuthenticationAfterUnauthorizedResponse() async throws {
    let contextID = MockContextIdentifier()
    let url = HTTPRequestURL(try #require(URL(string: "https://api.example.com/auth")))
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }

    MockURLProtocol.stubSequential(
      url: url,
      responses: [
        .success(statusCode: 401, data: HTTPBody(Data("expired".utf8))),
        .success(statusCode: 200, data: HTTPBody(Data("authorized".utf8))),
      ],
      contextID: contextID
    )

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }

    let tokenProvider = MockBearerTokenProvider()
    tokenProvider.stubToken("old-token")
    tokenProvider.stubRefreshToken("new-token")

    let client = try NetworkClient {
      CustomSession(session)
      Authentication {
        BearerToken(tokenProvider)
        AuthRefreshStrategyComponent.automatic()
      }
    }

    let response = try await client.execute(HTTPRequest(method: .get, url: url))
    let requests = await MockURLProtocol.getCapturedRequests(contextID: contextID)
    let firstRequest = try #require(requests.first)
    let retriedRequest = try #require(requests.dropFirst().first)

    #expect(response.status == .ok)
    #expect(response.body == HTTPBody(Data("authorized".utf8)))
    #expect(tokenProvider.getRefreshCount() == 1)
    #expect(requests.count == 2)
    #expect(firstRequest.value(forHTTPHeaderField: "Authorization") == "Bearer old-token")
    #expect(retriedRequest.value(forHTTPHeaderField: "Authorization") == "Bearer new-token")
  }

  @Test("A retryable 5xx response retries until a successful response")
  func retriesServerErrorResponses() async throws {
    let contextID = MockContextIdentifier()
    let url = HTTPRequestURL(try #require(URL(string: "https://api.example.com/retry")))
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }

    MockURLProtocol.stubSequential(
      url: url,
      responses: [
        .success(statusCode: 500, data: HTTPBody(Data("first failure".utf8))),
        .success(statusCode: 503, data: HTTPBody(Data("second failure".utf8))),
        .success(statusCode: 200, data: HTTPBody(Data("recovered".utf8))),
      ],
      contextID: contextID
    )

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }

    let client = try NetworkClient {
      CustomSession(session)
      Retry {
        MaxAttempts(2)
        BackoffStrategyComponent.fixed()
        InitialDelay(0)
      }
    }

    let response = try await client.execute(HTTPRequest(method: .get, url: url))
    let requestCount = await MockURLProtocol.getRequestCount(for: url, contextID: contextID)

    #expect(response.status == .ok)
    #expect(response.body == HTTPBody(Data("recovered".utf8)))
    #expect(requestCount == 3)
  }

  @Test("A configured cache replaces a 304 with the cached response")
  func returnsCachedResponseAfterNotModified() async throws {
    let contextID = MockContextIdentifier()
    let url = HTTPRequestURL(try #require(URL(string: "https://api.example.com/cached")))
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }

    MockURLProtocol.stubSequential(
      url: url,
      responses: [
        .success(
          statusCode: 200,
          data: HTTPBody(Data("cached body".utf8)),
          headers: ["ETag": "\"version-1\""]
        ),
        .success(statusCode: 304, data: HTTPBody(Data())),
      ],
      contextID: contextID
    )

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }

    let client = try NetworkClient {
      CustomSession(session)
      Caching {
        Policy.standard()
        Duration.ttl(0)
      }
    }
    let request = HTTPRequest(method: .get, url: url)

    _ = try await client.execute(request)
    let response = try await client.execute(request)
    let requests = await MockURLProtocol.getCapturedRequests(contextID: contextID)
    let revalidationRequest = try #require(requests.dropFirst().first)

    #expect(response.status == .ok)
    #expect(response.body == HTTPBody(Data("cached body".utf8)))
    #expect(requests.count == 2)
    #expect(revalidationRequest.value(forHTTPHeaderField: "If-None-Match") == "\"version-1\"")
  }
}
