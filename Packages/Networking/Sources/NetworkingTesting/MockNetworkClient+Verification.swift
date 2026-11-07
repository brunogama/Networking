import NetworkingCore

extension MockNetworkClient {
  /// Throws an assertion error describing expectations whose observed counts do not match.
  public func verifyExpectations() throws(AssertionError) {
    let missing = getUnfulfilledExpectations()
    guard missing.isEmpty else {
      throw AssertionError(UserMessageText(missing.map(\.rawValue).joined(separator: "\n")))
    }
  }

  /// Returns whether every registered expectation has its required call count.
  public func areExpectationsFulfilled() -> ExpectationFulfillmentFlag {
    ExpectationFulfillmentFlag(expectations.allSatisfy(\.isFulfilled))
  }

  /// Describes each expectation whose observed count does not match.
  public func getUnfulfilledExpectations() -> [ExpectationDescriptionText] {
    expectations.filter { !$0.isFulfilled }.map { ExpectationDescriptionText($0.description) }
  }

  /// Returns the requests recorded since initialization or the last clear.
  public func getRequestHistory() -> [HTTPRequest] { requestHistory }

  /// Returns recorded requests accepted by the supplied predicate.
  public func getRequests(matching predicate: HTTPRequestPredicate) -> [HTTPRequest] {
    requestHistory.filter(predicate.matches)
  }

  /// Counts recorded requests with the specified path, regardless of method.
  public func getRequestCount(for path: MockRequestPath) -> RequestCount {
    RequestCount(requestHistory.filter { $0.url.rawValue.path == path.rawValue }.count)
  }

  /// Clears request history while retaining expectations and their observed counts.
  public func clearRequestHistory() { requestHistory.removeAll() }
}
