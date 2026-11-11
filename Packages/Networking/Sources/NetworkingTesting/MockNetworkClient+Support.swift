import NetworkingCore

// MARK: - Swift Testing Integration

#if canImport(Testing)
import Testing

extension MockNetworkClient {

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
