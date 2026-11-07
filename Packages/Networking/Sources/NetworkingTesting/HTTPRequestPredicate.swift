import NetworkingCore

/// A Sendable predicate for inspecting recorded requests.
public struct HTTPRequestPredicate: Sendable {
  private let evaluator: @Sendable (HTTPRequest) -> MockPredicateMatchFlag

  /// Stores the request predicate without erasing its Sendable guarantee.
  public init(_ evaluator: @escaping @Sendable (HTTPRequest) -> MockPredicateMatchFlag) {
    self.evaluator = evaluator
  }

  func matches(_ request: HTTPRequest) -> Bool { evaluator(request).rawValue }
}
