import NetworkingRuntime

public struct HTTPRequestPredicate: Sendable {
  private let evaluator: @Sendable (HTTPRequest) -> MockPredicateMatchFlag

  public init(_ evaluator: @escaping @Sendable (HTTPRequest) -> MockPredicateMatchFlag) {
    self.evaluator = evaluator
  }

  func matches(_ request: HTTPRequest) -> Bool {
    evaluator(request).rawValue
  }
}

// MARK: - Error Types

/// Error thrown when expectations are not fulfilled
public struct AssertionError: Error, CustomStringConvertible {
  public let message: UserMessageText

  public init(_ message: UserMessageText) {
    self.message = message
  }

  public var description: String {
    message.rawValue
  }
}

// MARK: - Swift Testing Integration

#if canImport(Testing)
import Testing

extension MockNetworkClient {
  /// Verify expectations using Swift Testing framework
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

  /// Assert that a specific request was made
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
        MockPredicateMatchFlag(request.url.path == path.rawValue && request.method == method)
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
