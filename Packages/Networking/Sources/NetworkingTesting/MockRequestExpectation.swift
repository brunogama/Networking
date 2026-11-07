import Foundation
import NetworkingCore

struct MockRequestExpectation: Sendable {
  let matchers: [MockURLProtocol.RequestMatcher]
  let response: MockURLProtocol.MockResponse
  let expectedCalls: MockCallCountExpectation
  let capture: (@Sendable (HTTPRequest) -> Void)?
  var actualCalls = 0

  var isFulfilled: Bool { expectedCalls.matches(actualCalls) }

  var description: String {
    let criteria = matchers.map(\.description).joined(separator: ", ")
    return "Expected [\(criteria)] \(expectedCalls.description); received \(actualCalls) call(s)"
  }

  func matches(_ request: HTTPRequest) -> Bool {
    var candidate = URLRequest(url: request.url.rawValue)
    candidate.httpMethod = request.method.rawValue.rawValue
    candidate.httpBody = request.body?.rawValue
    candidate.allHTTPHeaderFields = request.headers.rawValue
    return matchers.allSatisfy { $0.matches(candidate) }
  }
}
