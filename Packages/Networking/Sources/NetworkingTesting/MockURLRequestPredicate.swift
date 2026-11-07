import Foundation
import NetworkingCore

/// A concurrent-safe predicate for matching intercepted URL requests.
public struct MockURLRequestPredicate: Sendable {
  private let evaluator: @Sendable (URLRequest) -> MockPredicateMatchFlag

  /// Stores a predicate that may be called from concurrent protocol callbacks.
  public init(_ evaluator: @escaping @Sendable (URLRequest) -> MockPredicateMatchFlag) {
    self.evaluator = evaluator
  }

  func matches(_ request: URLRequest) -> Bool {
    evaluator(request).rawValue
  }
}
