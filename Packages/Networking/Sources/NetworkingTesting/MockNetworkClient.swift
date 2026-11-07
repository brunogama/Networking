import Foundation
import NetworkingCore

/// An actor that registers complete expectations and records each request atomically.
///
/// Response configuration is captured before execution suspends. Reset clears this client's history
/// and expectations without changing other clients or URLProtocol sessions.
public actor MockNetworkClient: HTTPClient {
  var expectations: [MockRequestExpectation] = []
  var requestHistory: [HTTPRequest] = []
  private var recordsRequests: Bool
  let codec: JSONCodec

  public init(recordRequests: RequestRecordingEnabledFlag = true, codec: JSONCodec = JSONCodec()) {
    recordsRequests = recordRequests.rawValue
    self.codec = codec
  }

  public func expect(
    matching matchers: MockURLProtocol.RequestMatcher...,
    response: MockURLProtocol.MockResponse = .success(statusCode: 200, data: HTTPBody(Data())),
    calls: MockCallCountExpectation = .atLeast(1),
    capture: (@Sendable (HTTPRequest) -> Void)? = nil
  ) {
    expectations.append(
      MockRequestExpectation(
        matchers: matchers,
        response: response,
        expectedCalls: calls,
        capture: capture
      )
    )
  }

  public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    try Task.checkCancellation()
    if recordsRequests { requestHistory.append(request) }
    let response = try recordMatches(for: request)
    return try await response.toHTTPResponse(for: request)
  }

  private func recordMatches(for request: HTTPRequest) throws -> MockURLProtocol.MockResponse {
    var response: MockURLProtocol.MockResponse?
    var captures: [@Sendable (HTTPRequest) -> Void] = []
    for index in expectations.indices where expectations[index].matches(request) {
      expectations[index].actualCalls += 1
      response = response ?? expectations[index].response
      if let capture = expectations[index].capture { captures.append(capture) }
    }
    guard let response else {
      throw HTTPError(category: .configuration("No mock expectation matched"), request: request)
    }
    for capture in captures { capture(request) }
    return response
  }

  public func reset() {
    expectations.removeAll()
    requestHistory.removeAll()
  }

  public func setRequestRecording(enabled: RequestRecordingEnabledFlag) {
    recordsRequests = enabled.rawValue
  }
}
