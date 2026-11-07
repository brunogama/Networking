import Foundation
import NetworkingCore

/// Request stub configuration.
public struct MockURLRequestStub: Sendable {
  let matchers: [MockURLProtocol.RequestMatcher]
  let response: MockURLProtocol.MockResponse
  let maxUsageCount: MockVerificationCount?
  let requestCapture: (@Sendable (URLRequest) -> Void)?
  let contextID: MockContextIdentifier?

  /// Defines a response, usage limit, capture callback, and optional test context.
  public init(
    matchers: [MockURLProtocol.RequestMatcher],
    response: MockURLProtocol.MockResponse,
    maxUsageCount: MockVerificationCount? = nil,
    requestCapture: (@Sendable (URLRequest) -> Void)? = nil,
    contextID: MockContextIdentifier? = nil
  ) {
    self.matchers = matchers
    self.response = response
    self.maxUsageCount = maxUsageCount
    self.requestCapture = requestCapture
    self.contextID = contextID
  }

  func matches(_ request: URLRequest) -> Bool {
    if let contextID,
      request.value(forHTTPHeaderField: MockURLProtocol.contextHeader)
        != contextID.rawValue.uuidString
    {
      return false
    }
    return matchers.allSatisfy { $0.matches(request) }
  }
}
