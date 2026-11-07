import Foundation
import NetworkingCore
import NetworkingRuntime

extension MockURLProtocol {
  /// Get all captured requests.
  /// - Returns: Array of all requests that were handled by the mock
  public static func getCapturedRequests(
    contextID: MockContextIdentifier? = nil
  ) async -> [URLRequest] {
    mockState.getCapturedRequests(contextID: contextID)
  }

  /// Get request count for a specific URL.
  /// - Parameters:
  ///   - url: The URL to check.
  ///   - contextID: Limits inspection to a specific test session.
  /// - Returns: Number of times requests were made to this URL
  public static func getRequestCount(
    for url: HTTPRequestURL,
    contextID: MockContextIdentifier? = nil
  ) async -> MockVerificationCount {
    mockState.getRequestCount(for: url, contextID: contextID)
  }

  /// Verify that a request was made.
  /// - Parameters:
  ///   - url: The URL that should have been requested
  ///   - method: Optional HTTP method to verify
  ///   - count: Expected number of requests (default: at least 1)
  ///   - contextID: Limits inspection to a specific test session.
  /// - Returns: True if verification passes
  public static func verifyRequest(
    url: HTTPRequestURL,
    method: HTTPMethod? = nil,
    count: MockVerificationCount = 1,
    contextID: MockContextIdentifier? = nil
  ) async -> MockPredicateMatchFlag {
    let requests = await getCapturedRequests(contextID: contextID)
    let matchingRequests = requests.filter { request in
      let urlMatches = request.url == url.rawValue
      let methodMatches =
        method.map { request.httpMethod?.uppercased() == $0.rawValue.rawValue.uppercased() } ?? true
      return urlMatches && methodMatches
    }
    return MockPredicateMatchFlag(matchingRequests.count >= count.rawValue)
  }

  /// Clear all stubs and captured requests.
  public static func clearAll(contextID: MockContextIdentifier? = nil) {
    mockState.clearAll(contextID: contextID)
  }

  /// Get current stub count for testing/debugging.
  public static func getStubCount() async -> MockVerificationCount {
    mockState.getStubCount()
  }

  // MARK: - Convenience Methods

  /// Create a URLSessionConfiguration configured with MockURLProtocol.
  /// - Returns: URLSessionConfiguration ready for testing
  public static func createMockConfiguration(
    contextID: MockContextIdentifier? = nil
  ) -> URLSessionConfiguration {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    if let contextID {
      var headers = config.httpAdditionalHeaders ?? [:]
      headers[contextHeader] = contextID.rawValue.uuidString
      config.httpAdditionalHeaders = headers
    }
    // Disable caching to ensure fresh responses for each request
    config.urlCache = nil
    config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    return config
  }

  /// Create an HTTPClient configured with MockURLProtocol.
  /// - Returns: HTTPClient instance ready for testing
  public static func createMockHTTPClient(contextID: MockContextIdentifier? = nil) -> HTTPClient {
    let config = createMockConfiguration(contextID: contextID)
    return NetworkClient(session: URLSession(configuration: config))
  }
}
