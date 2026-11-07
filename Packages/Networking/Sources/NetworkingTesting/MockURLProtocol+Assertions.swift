import NetworkingCore

#if canImport(Testing)
import Testing

extension MockURLProtocol {
  /// Assert that a request was made with Swift Testing.
  /// - Parameters:
  ///   - url: The URL that should have been requested
  ///   - method: Optional HTTP method to verify
  ///   - count: Expected number of requests
  ///   - contextID: Limits inspection to a specific test session.
  ///   - sourceLocation: Source location for failure reporting.
  public static func expectRequest(
    url: HTTPRequestURL,
    method: HTTPMethod? = nil,
    count: MockVerificationCount = 1,
    contextID: MockContextIdentifier? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async {
    let verified = await verifyRequest(url: url, method: method, count: count, contextID: contextID)
    #expect(
      verified.rawValue,
      "Expected \(count) request(s) to \(url.rawValue.absoluteString), but verification failed",
      sourceLocation: sourceLocation
    )
  }

  /// Assert that no requests were made to a URL.
  /// - Parameters:
  ///   - url: The URL that should not have been requested
  ///   - contextID: Limits inspection to a specific test session.
  ///   - sourceLocation: Source location for failure reporting.
  public static func expectNoRequest(
    url: HTTPRequestURL,
    contextID: MockContextIdentifier? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async {
    let count = await getRequestCount(for: url, contextID: contextID)
    #expect(
      count == 0,
      "Expected no requests to \(url.rawValue.absoluteString), but found \(count)",
      sourceLocation: sourceLocation
    )
  }
}

#endif
