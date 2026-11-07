import NetworkingCore

// MARK: - Swift Testing Integration

#if canImport(Testing)
import Testing

extension MockNetworkClient {
  /// Verifies expectations using the Swift Testing framework.
  /// - Parameter sourceLocation: Source location for error reporting
  public func expectationsAreFulfilled(
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let unfulfilled = getUnfulfilledExpectations()
    #expect(
      unfulfilled.isEmpty,
      "Unfulfilled expectations: \(unfulfilled.map(\.rawValue).joined(separator: ", "))",
      sourceLocation: sourceLocation
    )
  }

  /// Asserts that a specific request was made.
  /// - Parameters:
  ///   - path: URL path that should have been requested
  ///   - method: HTTP method
  ///   - count: Expected number of requests
  ///   - sourceLocation: Source location for error reporting
  public func expectRequest(
    path: MockRequestPath,
    method: HTTPMethod,
    count: RequestCount = 1,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let matchingRequests = getRequests(
      matching: HTTPRequestPredicate { request in
        MockPredicateMatchFlag(
          request.url.rawValue.path == path.rawValue && request.method == method
        )
      }
    )
    #expect(
      matchingRequests.count == count.rawValue,
      "Expected \(count.rawValue) \(method.rawValue) requests to \(path.rawValue), but found \(matchingRequests.count)",
      sourceLocation: sourceLocation
    )
  }
}

#endif
