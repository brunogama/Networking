import NetworkingCore

extension MockNetworkClient {

  public func verifyExpectations() throws(AssertionError) {
    let missing = getUnfulfilledExpectations()
    guard missing.isEmpty else {
      throw AssertionError(UserMessageText(missing.map(\.rawValue).joined(separator: "\n")))
    }
  }

  public func areExpectationsFulfilled() -> ExpectationFulfillmentFlag {
    ExpectationFulfillmentFlag(expectations.allSatisfy(\.isFulfilled))
  }

  public func getUnfulfilledExpectations() -> [ExpectationDescriptionText] {
    expectations.filter { !$0.isFulfilled }.map { ExpectationDescriptionText($0.description) }
  }

  public func getRequestHistory() -> [HTTPRequest] { requestHistory }

  public func getRequests(matching predicate: HTTPRequestPredicate) -> [HTTPRequest] {
    requestHistory.filter(predicate.matches)
  }

  public func getRequestCount(for path: MockRequestPath) -> RequestCount {
    RequestCount(requestHistory.filter { $0.url.rawValue.path == path.rawValue }.count)
  }

  public func clearRequestHistory() { requestHistory.removeAll() }
}
