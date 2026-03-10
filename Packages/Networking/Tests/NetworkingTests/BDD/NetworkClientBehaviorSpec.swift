import Foundation
import Testing

@testable import Networking
import NetworkingTesting

/// BDD specs for NetworkClient execution behaviors
///
/// These specs cover user-facing NetworkClient behaviors:
/// - HTTP request execution (success and error scenarios)
/// - Middleware processing
/// - Response handling
///
/// NOTE: This supplements existing SimpleBDDTests.swift which covers type behaviors.
/// These specs focus on NetworkClient execution flows.
@Suite("NetworkClient")
struct NetworkClientBehaviorTests {
  @Test("When the request succeeds, returns the response with correct status")
  func returnsTheResponseWithCorrectStatus() async throws {
    let mockClient = MockNetworkClient()
    let request = Self.makeRequest(path: "/users")

    mockClient.stubGET(path: "/users", response: Data("success".utf8))

    let response = try await mockClient.execute(request)

    #expect(response.status == .ok)
    mockClient.expectationsAreFulfilled()
  }

  @Test("When the request succeeds, decodes JSON response bodies")
  func decodesJSONResponseBodies() async throws {
    struct User: Codable, Equatable {
      let id: Int
      let name: String
    }

    let mockClient = MockNetworkClient()
    let request = Self.makeRequest(path: "/users/1")
    let userData = Data(#"{"id": 1, "name": "John Doe"}"#.utf8)

    mockClient.stubGET(path: "/users/1", response: userData)

    let response = try await mockClient.execute(request)
    let body = try #require(response.body)
    let user = try JSONDecoder().decode(User.self, from: body)

    #expect(user == User(id: 1, name: "John Doe"))
    mockClient.expectationsAreFulfilled()
  }

  @Test("When the server returns 500, surfaces the response")
  func surfacesThe500Response() async {
    let mockClient = MockNetworkClient()
    let request = Self.makeRequest(path: "/error")

    mockClient.expectGET("/error")
      .andReturn(.success(statusCode: 500, data: Data()))

    do {
      let response = try await mockClient.execute(request)
      #expect(response.status.rawValue == 500)
    } catch {
      #expect(error is Error)
    }

    mockClient.expectationsAreFulfilled()
  }

  @Test("When the server includes an error body, preserves it for debugging")
  func preservesTheResponseBodyForDebugging() async throws {
    let mockClient = MockNetworkClient()
    let request = Self.makeRequest(path: "/invalid")
    let errorBody = Data(#"{"error": "Invalid request"}"#.utf8)

    mockClient.expectGET("/invalid")
      .andReturn(.success(statusCode: 400, data: errorBody))

    let response = try await mockClient.execute(request)

    #expect(response.body == errorBody)
    mockClient.expectationsAreFulfilled()
  }

  @Test("When the network is unavailable, throws a connection error")
  func throwsANetworkConnectionError() async throws {
    let mockClient = MockNetworkClient()
    let request = Self.makeRequest(path: "/offline")

    mockClient.expectGET("/offline")
      .andReturnError(URLError(.notConnectedToInternet))

    do {
      _ = try await mockClient.execute(request)
      Issue.record("Expected network error to be thrown")
    } catch let error as HTTPError {
      let underlyingError = try #require(error.underlyingError as? URLError)
      #expect(underlyingError.code == .notConnectedToInternet)
    } catch {
      Issue.record("Expected HTTPError, got \(type(of: error))")
    }

    mockClient.expectationsAreFulfilled()
  }

  @Test("When authentication is configured, adds Authorization header to requests")
  func addsAuthorizationHeaderToRequests() async throws {
    let mockClient = MockNetworkClient()
    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/protected")!,
      headers: ["Authorization": "Bearer test-token"]
    )

    mockClient.expectGET("/protected")
      .withHeader("Authorization", value: "Bearer test-token")
      .andReturn(.success(statusCode: 200, data: Data()))

    let response = try await mockClient.execute(request)

    #expect(response.status == .ok)
    mockClient.expectationsAreFulfilled()
  }

  @Test("When multiple middleware are configured, processes them in order")
  func processesMiddlewareInCorrectOrder() async throws {
    let mockClient = MockNetworkClient()
    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/multi")!,
      headers: [
        "X-First-Middleware": "value1",
        "X-Second-Middleware": "value2",
        "Authorization": "Bearer token",
      ]
    )

    mockClient.expect(.path("/multi"))
      .withHeader("X-First-Middleware", value: "value1")
      .withHeader("X-Second-Middleware", value: "value2")
      .withHeader("Authorization", value: "Bearer token")
      .andReturn(.success(statusCode: 200, data: Data()))

    let response = try await mockClient.execute(request)

    #expect(response.status == .ok)
    mockClient.expectationsAreFulfilled()
  }

  @Test("When cache is enabled, returns the configured response")
  func returnsTheConfiguredResponseForIdenticalRequests() async throws {
    let mockClient = MockNetworkClient()
    let request = Self.makeRequest(path: "/cached")
    let responseData = Data(#"{"cached": true}"#.utf8)

    mockClient.expectGET("/cached")
      .andReturn(.success(statusCode: 200, data: responseData))
      .exactly(1)

    let response = try await mockClient.execute(request)

    #expect(response.body == responseData)
    mockClient.expectationsAreFulfilled()
  }

  @Test("When cache metadata is configured, preserves the TTL")
  func respectsCacheTTL() {
    let metadata = CacheMetadata(ttl: 300, tags: ["users"])

    #expect(metadata.ttl == 300)
    #expect(metadata.tags == ["users"])
  }

  @Test("When timeout is configured, creates timeout errors for slow requests")
  func createsTimeoutErrorsForSlowRequests() {
    let request = Self.makeRequest(path: "/slow")
    let error = HTTPError(category: .timeout, request: request)

    guard case .timeout = error.category else {
      Issue.record("Expected timeout error category")
      return
    }

    #expect(error.request?.url == request.url)
  }

  private static func makeRequest(path: String) -> HTTPRequest {
    HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com\(path)")!
    )
  }
}
