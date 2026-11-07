import NetworkingCore

#if canImport(Testing)
import Testing

extension MockURLProtocol {

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
