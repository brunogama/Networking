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
  @Test("Authentication retries the request after base URL middleware resolves it")
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
    tokenProvider.stubToken("old-token")
    tokenProvider.stubRefreshToken("new-token")

    let client = try NetworkClient {
      CustomSession(session)
      BaseURL(baseURL)
      Authentication {
        BearerToken(tokenProvider)
        AuthRefreshStrategyComponent.automatic()
      }
    }

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

    let configuration = MockURLProtocol.createMockConfiguration(contextID: contextID)
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let client = try NetworkClient {
      CustomSession(session)
      Retry {
        MaxAttempts(1)
        BackoffStrategyComponent.fixed()
        InitialDelay(0)
      }
      Caching {
        Policy.standard()
        Duration.ttl(0)
      }
    }
    let request = HTTPRequest(method: .get, url: url)

    let recovered = try await client.execute(request)
    let revalidated = try await client.execute(request)
    let requests = await MockURLProtocol.getCapturedRequests(contextID: contextID)

    #expect(recovered.status == .ok)
    #expect(revalidated.status == .ok)
    #expect(revalidated.body == HTTPBody(Data("recovered".utf8)))
    #expect(requests.count == 3)
  }
}
