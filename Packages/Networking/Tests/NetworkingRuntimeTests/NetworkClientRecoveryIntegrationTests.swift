import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite("NetworkClient recovery integration")
struct NetworkClientRecoveryIntegrationTests {
  @Test("Authentication retries the request after client configuration resolves its base URL")
  func refreshesAuthenticationForRelativeURL() async throws {
    let contextID = MockContextIdentifier()
    let baseURL = HTTPRequestURL(try #require(URL(string: "https://api.example.com")))
    let resolvedURL = HTTPRequestURL(try #require(URL(string: "https://api.example.com/auth")))
    let relativeURL = HTTPRequestURL(try #require(URL(string: "auth")))
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }

    MockURLProtocol.stubSequential(
      url: resolvedURL,
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
    await tokenProvider.stubToken("old-token")
    await tokenProvider.stubRefreshToken("new-token")

    var configuration = NetworkClient.Configuration()
    configuration.baseURL = baseURL.rawValue
    let authentication = AuthenticationMiddleware(
      configuration: .init(),
      tokenProvider: tokenProvider,
      client: NetworkClient(session: session)
    )
    let client = NetworkClient(
      session: session,
      middleware: HTTPMiddleware(request: [authentication], error: [authentication]),
      configuration: configuration
    )

    let response = try await client.execute(HTTPRequest(method: .get, url: relativeURL))
    let requests = await MockURLProtocol.getCapturedRequests(contextID: contextID)

    #expect(response.status == .ok)
    #expect(response.body == HTTPBody(Data("authorized".utf8)))
    #expect(requests.count == 2)
    #expect(requests.allSatisfy { $0.url == resolvedURL.rawValue })
  }

  @Test("A recovered response passes through caching middleware")
  func cachesResponseRecoveredByRetry() async throws {
    let contextID = MockContextIdentifier()
    let url = HTTPRequestURL(try #require(URL(string: "https://api.example.com/retry-cached")))
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }

    stubRecoveryResponses(url: url, contextID: contextID)

    let configuration = MockURLProtocol.createMockConfiguration(contextID: contextID)
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let transport = NetworkClient(session: session)
    let retry = RetryMiddleware(
      configuration: try .init(maxAttempts: 1, initialDelay: .zero),
      client: transport
    )
    let cache = CachingMiddleware(
      configuration: .init(defaultTTL: 0),
      storage: MemoryCacheStorage(),
      client: transport
    )
    let client = NetworkClient(
      session: session,
      middleware: HTTPMiddleware(request: [cache], response: [cache], error: [retry])
    )
    let request = HTTPRequest(method: .get, url: url)

    let recovered = try await client.execute(request)
    let revalidated = try await client.execute(request)
    let requests = await MockURLProtocol.getCapturedRequests(contextID: contextID)

    #expect(recovered.status == .ok)
    #expect(revalidated.status == .ok)
    #expect(revalidated.body == HTTPBody(Data("recovered".utf8)))
    #expect(requests.count == 3)
  }
  private func stubRecoveryResponses(url: HTTPRequestURL, contextID: MockContextIdentifier) {
    MockURLProtocol.stubSequential(
      url: url,
      responses: [
        .success(statusCode: 500, data: HTTPBody(Data("failure".utf8))),
        .success(
          statusCode: 200,
          data: HTTPBody(Data("recovered".utf8)),
          headers: ["ETag": "\"version-1\""]
        ),
        .success(statusCode: 304, data: HTTPBody(Data())),
      ],
      contextID: contextID
    )
  }
}
