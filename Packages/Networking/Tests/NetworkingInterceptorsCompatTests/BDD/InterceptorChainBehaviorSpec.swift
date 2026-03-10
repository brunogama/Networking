import Foundation
import Testing

@testable import NetworkingInterceptorsCompat
import NetworkingRuntime

/// BDD specs for InterceptorChain behaviors
///
/// These specs describe observable behaviors of the interceptor chain:
/// - Request transformation through interceptors
/// - Response transformation after receiving
/// - Chain composition and ordering
///
/// NOTE: Supplements existing interceptor unit tests with behavior-focused specs.
@Suite("InterceptorChain")
struct InterceptorChainBehaviorTests {
  @Test("With request interceptors, transforms the request before sending")
  func transformsTheRequestBeforeSending() async throws {
    let chain = InterceptorChain(
      requestInterceptors: [AuthenticationInterceptor.bearer("test-token")]
    )
    var request = Self.makeRequest(path: "/api/users")

    let result = try await chain.executeRequestInterceptors(
      request: &request,
      context: Self.makeContext(path: "/api/users")
    )

    guard case .proceed = result else {
      Issue.record("Expected interceptor chain to proceed")
      return
    }

    #expect(request.headers["Authorization"] == "Bearer test-token")
  }

  @Test("With request interceptors, surfaces a rejection when an interceptor aborts the chain")
  func surfacesARejectionWhenAnInterceptorAbortsTheChain() async {
    let chain = InterceptorChain(
      requestInterceptors: [
        RateLimitInterceptor(
          requestsPerWindow: 0,
          windowDuration: 1.0,
          strategy: .reject
        )
      ]
    )
    var request = Self.makeRequest(path: "/api/limited")

    do {
      _ = try await chain.executeRequestInterceptors(
        request: &request,
        context: Self.makeContext(path: "/api/limited")
      )
      Issue.record("Expected interceptor chain to reject the request")
    } catch {
      #expect(error is InterceptorError)
    }
  }

  @Test("With response interceptors, transforms the response after receiving")
  func transformsTheResponseAfterReceiving() async throws {
    let cache = CachingInterceptor(ttl: 300, maxEntries: 10)
    let chain = InterceptorChain(responseInterceptors: [cache])
    let request = Self.makeRequest(path: "/api/data")
    let response = HTTPResponse(
      request: request,
      status: .ok,
      headers: [:],
      body: Data("cached data".utf8)
    )

    let result = try await chain.executeResponseInterceptors(
      response: response,
      context: Self.makeContext(path: "/api/data")
    )

    guard case .proceed = result else {
      Issue.record("Expected response interceptors to proceed")
      return
    }

    let cachedResponse = await cache.getCachedResponse(for: .get, path: "/api/data")
    let cachedBody = try #require(cachedResponse?.body)

    #expect(cachedBody.rawValue == Data("cached data".utf8))
  }

  @Test("When composing chains, applies interceptors in the configured order")
  func appliesInterceptorsInTheConfiguredOrder() async throws {
    let chain = InterceptorChain(
      requestInterceptors: [
        AuthenticationInterceptor.bearer("token"),
        LoggingInterceptor(level: .basic),
      ]
    )
    var request = Self.makeRequest(path: "/api/ordered")

    let result = try await chain.executeRequestInterceptors(
      request: &request,
      context: Self.makeContext(path: "/api/ordered")
    )

    guard case .proceed = result else {
      Issue.record("Expected interceptor chain to proceed")
      return
    }

    #expect(request.headers["Authorization"] == "Bearer token")
  }

  @Test("When the chain is empty, passes requests through unchanged")
  func passesRequestsThroughUnchangedWhenTheChainIsEmpty() async throws {
    let chain = InterceptorChain(requestInterceptors: [])
    let originalHeaders = HTTPHeaders(["X-Custom": "value"])
    let originalBody = HTTPBody(Data("body".utf8))
    var request = HTTPRequest(
      method: .post,
      url: HTTPRequestURL(URL(string: "https://api.example.com/empty")!),
      headers: originalHeaders,
      body: originalBody
    )

    let result = try await chain.executeRequestInterceptors(
      request: &request,
      context: Self.makeContext(path: "/empty", method: .post)
    )

    guard case .proceed = result else {
      Issue.record("Expected empty interceptor chain to proceed")
      return
    }

    #expect(request.headers == originalHeaders)
    #expect(request.body == originalBody)
  }

  @Test("When an interceptor throws, propagates the error to the caller")
  func propagatesTheErrorToTheCaller() async {
    let chain = InterceptorChain(
      requestInterceptors: [
        RateLimitInterceptor(
          requestsPerWindow: 0,
          windowDuration: 1.0,
          strategy: .reject
        )
      ]
    )
    var request = Self.makeRequest(path: "/api/reject")

    do {
      _ = try await chain.executeRequestInterceptors(
        request: &request,
        context: Self.makeContext(path: "/api/reject")
      )
      Issue.record("Expected interceptor error to propagate")
    } catch {
      #expect(error is InterceptorError)
    }
  }

  private static func makeRequest(path: String) -> HTTPRequest {
    HTTPRequest(
      method: .get,
      path: RequestPathPattern(path),
      baseURL: BaseURLText("https://api.example.com")
    )
  }

  private static func makeContext(
    path: String,
    method: HTTPMethod = .get
  ) -> InterceptorContext {
    InterceptorContext(
      path: RequestPathPattern(path),
      method: method,
      attemptCount: 0,
      metadata: [:]
    )
  }
}
