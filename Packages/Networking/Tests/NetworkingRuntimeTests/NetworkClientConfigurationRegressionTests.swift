import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite("NetworkClient configuration behavior")
struct ClientConfigRegressionTests {
  @Test("DefaultTimeout reaches URLSession when the request has no override")
  func defaultTimeoutIsApplied() async throws {
    let contextID = MockContextIdentifier()
    let url = HTTPRequestURL(try #require(URL(string: "https://example.com/default-timeout")))
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }
    MockURLProtocol.stub(
      matching: .url(url),
      response: .success(statusCode: 200, data: HTTPBody(Data())),
      contextID: contextID
    )

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }

    let client = try NetworkClient {
      CustomSession(session)
      DefaultTimeout(9)
    }
    _ = try await client.execute(HTTPRequest(method: .get, url: url))

    let request = try #require(
      await MockURLProtocol.getCapturedRequests(contextID: contextID).first
    )
    #expect(request.timeoutInterval == 9)
  }

  @Test("A session timeout reaches URLSession when the request has no override")
  func sessionTimeoutIsInherited() async throws {
    let contextID = MockContextIdentifier()
    let url = HTTPRequestURL(try #require(URL(string: "https://example.com/session-timeout")))
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }
    MockURLProtocol.stub(
      matching: .url(url),
      response: .success(statusCode: 200, data: HTTPBody(Data())),
      contextID: contextID
    )

    let configuration = MockURLProtocol.createMockConfiguration(contextID: contextID)
    configuration.timeoutIntervalForRequest = 7
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }

    let client = NetworkClient(session: session)
    _ = try await client.execute(HTTPRequest(method: .get, url: url))

    let request = try #require(
      await MockURLProtocol.getCapturedRequests(contextID: contextID).first
    )
    #expect(request.timeoutInterval == 7)
  }

  @Test("EnableRetry uses the configured session")
  func retryUsesConfiguredSession() async throws {
    let contextID = MockContextIdentifier()
    let url = HTTPRequestURL(try #require(URL(string: "https://example.com/legacy-retry")))
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }
    MockURLProtocol.stubSequential(
      url: url,
      responses: [
        .success(statusCode: 500, data: HTTPBody(Data())),
        .success(statusCode: 200, data: HTTPBody(Data("retried".utf8))),
      ],
      contextID: contextID
    )

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }

    let client = try NetworkClient {
      CustomSession(session)
      EnableRetry(
        RetryMiddleware.Configuration(
          maxAttempts: 1,
          baseDelay: 0,
          jitterStrategy: .none
        )
      )
    }

    let response = try await client.execute(HTTPRequest(method: .get, url: url))
    let count = await MockURLProtocol.getRequestCount(for: url, contextID: contextID)
    #expect(response.body == HTTPBody(Data("retried".utf8)))
    #expect(count == 2)
  }

  @Test(
    "URLSession transport errors retain their typed category",
    arguments: [
      (URLError.Code.timedOut, HTTPError.Category.timeout),
      (.networkConnectionLost, .network(.connectionLost)),
      (.notConnectedToInternet, .network(.noConnection)),
    ]
  )
  func transportErrorCategories(
    code: URLError.Code,
    expectedCategory: HTTPError.Category
  ) async throws {
    let contextID = MockContextIdentifier()
    let url = HTTPRequestURL(try #require(URL(string: "https://example.com/transport-error")))
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }
    MockURLProtocol.stub(
      matching: .url(url),
      response: .failure(URLError(code)),
      contextID: contextID
    )
    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }

    let client = NetworkClient(session: session)
    do {
      _ = try await client.execute(HTTPRequest(method: .get, url: url))
      Issue.record("Expected a transport error")
    } catch let error as HTTPError {
      #expect(error.category == expectedCategory)
    }
  }

  @Test("CustomSession and EnableSecurity fail configuration instead of dropping the session")
  func securityCannotReplaceCustomSession() throws {
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }

    #expect(throws: HTTPError.self) {
      try NetworkClient {
        CustomSession(session)
        EnableSecurity(SecurityConfiguration())
      }
    }
  }

  @Test("CustomSession and Session settings fail configuration instead of replacing each other")
  func sessionSettingsCannotReplaceCustomSession() throws {
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }

    #expect(throws: HTTPError.self) {
      try NetworkClient {
        CustomSession(session)
        Session {
          SessionTimeout(9)
        }
      }
    }
  }
}
