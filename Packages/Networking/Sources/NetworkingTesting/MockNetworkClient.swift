import NetworkingRuntime
import Foundation

/// Expectation-based mock network client for comprehensive testing
///
/// This mock client provides:
/// - Declarative request/response expectations
/// - Automatic request verification
/// - Flexible response stubbing
/// - Request history tracking
/// - Performance measurement integration
/// - Swift Testing framework integration
///
/// ## Usage Example
/// ```swift
/// let mockClient = MockNetworkClient()
///
/// // Set up expectations
/// mockClient.expect(.get("/users/123"))
///   .andReturn(.success(statusCode: 200, data: userData))
///   .once()
///
/// // Execute test
/// let response = try await mockClient.execute(request)
///
/// // Verify expectations
/// mockClient.verifyExpectations()
/// ```
///
/// - Note: `@unchecked Sendable` justification:
///   1. Test-only code, not production
///   2. Mutable state (`expectations`, `requestHistory`) protected by `DispatchQueue.concurrent` with barrier writes
///   3. All public methods synchronize access through concurrent queue
///   4. Tests run with explicit synchronization or serially
///   5. Acceptable tradeoff for test ergonomics and API simplicity
public final class MockNetworkClient: HTTPClient, @unchecked Sendable {
  // MARK: - Types

  public typealias RequestMatcher = MockURLProtocol.RequestMatcher

  /// Mock response configuration (re-exported from MockURLProtocol)
  public typealias MockResponse = MockURLProtocol.MockResponse

  // MARK: - State Management

  private let queue = DispatchQueue(label: "MockNetworkClient.queue", attributes: .concurrent)
  private var expectations: [RequestExpectation] = []
  private var requestHistory: [HTTPRequest] = []
  private var isRecordingRequests: Bool = true

  // MARK: - Initialization

  /// Creates a new mock network client
  /// - Parameter recordRequests: Whether to record request history (default: true)
  public init(
    recordRequests: RequestRecordingEnabledFlag = RequestRecordingEnabledFlag(rawValue: true)
  ) {
    self.isRecordingRequests = recordRequests.rawValue
  }

  // MARK: - Expectation Setup

  /// Create an expectation for a specific request
  /// - Parameter matcher: Request matching criteria
  /// - Returns: RequestExpectation for configuration
  @discardableResult
  public func expect(_ matcher: RequestMatcher) -> RequestExpectation {
    queue.sync(flags: .barrier) {
      let expectation = RequestExpectation(client: self, matcher: matcher)
      expectations.append(expectation)
      return expectation
    }
  }

  /// Expect a GET request
  /// - Parameter path: URL path to match
  /// - Returns: RequestExpectation for configuration
  @discardableResult
  public func expectGET(_ path: MockRequestPath) -> RequestExpectation {
    expect(.method(.get)).expect(.path(path))
  }

  /// Expect a POST request
  /// - Parameter path: URL path to match
  /// - Returns: RequestExpectation for configuration
  @discardableResult
  public func expectPOST(_ path: MockRequestPath) -> RequestExpectation {
    expect(.method(.post)).expect(.path(path))
  }

  /// Expect a PUT request
  /// - Parameter path: URL path to match
  /// - Returns: RequestExpectation for configuration
  @discardableResult
  public func expectPUT(_ path: MockRequestPath) -> RequestExpectation {
    expect(.method(.put)).expect(.path(path))
  }

  /// Expect a DELETE request
  /// - Parameter path: URL path to match
  /// - Returns: RequestExpectation for configuration
  @discardableResult
  public func expectDELETE(_ path: MockRequestPath) -> RequestExpectation {
    expect(.method(.delete)).expect(.path(path))
  }

  // MARK: - Request Execution

  public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    recordRequestIfNeeded(request)
    let expectation = try findMatchingExpectation(for: request)
    return try await expectation.mockResponse.toHTTPResponse(for: request)
  }

  // MARK: - Verification

  /// Verify all expectations have been fulfilled
  /// - Throws: AssertionError if any expectations are not fulfilled
  public func verifyExpectations() throws {
    let unfulfilled = queue.sync {
      expectations.filter { !$0.isFulfilled }
    }

    if !unfulfilled.isEmpty {
      let descriptions = unfulfilled.map { $0.expectationDescription }.joined(separator: "\n")
      throw AssertionError("Unfulfilled expectations:\n\(descriptions)")
    }
  }

  /// Check if all expectations are fulfilled without throwing
  /// - Returns: True if all expectations are fulfilled
  public func areExpectationsFulfilled() -> ExpectationFulfillmentFlag {
    ExpectationFulfillmentFlag(
      queue.sync {
        expectations.allSatisfy { $0.isFulfilled }
      }
    )
  }

  /// Get unfulfilled expectations
  /// - Returns: Array of unfulfilled expectation descriptions
  public func getUnfulfilledExpectations() -> [ExpectationDescriptionText] {
    queue.sync {
      expectations.filter { !$0.isFulfilled }.map {
        ExpectationDescriptionText($0.expectationDescription)
      }
    }
  }

  // MARK: - Request History

  /// Get all recorded requests
  /// - Returns: Array of all requests executed through this client
  public func getRequestHistory() -> [HTTPRequest] {
    queue.sync { requestHistory }
  }

  /// Get requests matching a specific predicate
  /// - Parameter predicate: Filtering predicate
  /// - Returns: Filtered requests
  public func getRequests(matching predicate: HTTPRequestPredicate) -> [HTTPRequest] {
    queue.sync {
      requestHistory.filter(predicate.matches)
    }
  }

  /// Get request count for a specific path
  /// - Parameter path: URL path to count
  /// - Returns: Number of requests to that path
  public func getRequestCount(for path: MockRequestPath) -> RequestCount {
    RequestCount(
      queue.sync {
        requestHistory.filter { $0.url.path == path.rawValue }.count
      }
    )
  }

  /// Clear all recorded requests
  public func clearRequestHistory() {
    queue.sync(flags: .barrier) {
      requestHistory.removeAll()
    }
  }

  // MARK: - State Management

  /// Clear all expectations and request history
  public func reset() {
    queue.sync(flags: .barrier) {
      expectations.removeAll()
      requestHistory.removeAll()
    }
    MockURLProtocol.clearAll()
  }

  /// Enable or disable request recording
  /// - Parameter enabled: Whether to record requests
  public func setRequestRecording(enabled: RequestRecordingEnabledFlag) {
    queue.sync(flags: .barrier) {
      isRecordingRequests = enabled.rawValue
    }
  }

  // MARK: - Convenience Methods

  /// Stub a simple GET request
  /// - Parameters:
  ///   - path: URL path
  ///   - response: Response data
  ///   - statusCode: HTTP status code
  public func stubGET(
    path: MockRequestPath,
    response: HTTPBody,
    statusCode: HTTPStatusCode = HTTPStatusCode(rawValue: 200)
  ) {
    expectGET(path)
      .andReturn(.success(statusCode: statusCode, data: response))
      .atLeastOnce()
  }

  package func stubGET(
    path: MockRequestPath,
    response: Data,
    statusCode: HTTPStatusCode = HTTPStatusCode(rawValue: 200)
  ) {
    stubGET(path: path, response: HTTPBody(response), statusCode: statusCode)
  }

  /// Stub a GET request with JSON response
  /// - Parameters:
  ///   - path: URL path
  ///   - json: Encodable object to return as JSON
  ///   - statusCode: HTTP status code
  public func stubGET<T: Encodable>(
    path: MockRequestPath,
    json: T,
    statusCode: HTTPStatusCode = HTTPStatusCode(rawValue: 200)
  ) throws {
    try expectGET(path)
      .andReturnJSON(json, statusCode: statusCode)
      .atLeastOnce()
  }

  /// Stub a POST request
  /// - Parameters:
  ///   - path: URL path
  ///   - response: Response data
  ///   - statusCode: HTTP status code
  public func stubPOST(
    path: MockRequestPath,
    response: HTTPBody,
    statusCode: HTTPStatusCode = 201
  ) {
    expectPOST(path)
      .andReturn(.success(statusCode: statusCode, data: response))
      .atLeastOnce()
  }

  package func stubPOST(
    path: MockRequestPath,
    response: Data,
    statusCode: HTTPStatusCode = 201
  ) {
    stubPOST(path: path, response: HTTPBody(response), statusCode: statusCode)
  }
}

extension MockNetworkClient {
  private func recordRequestIfNeeded(_ request: HTTPRequest) {
    guard isRecordingRequests else { return }

    queue.sync(flags: .barrier) {
      requestHistory.append(request)
    }
  }

  private func findMatchingExpectation(for request: HTTPRequest) throws -> RequestExpectation {
    let matchingExpectation = queue.sync(flags: .barrier) {
      var firstMatch: RequestExpectation?

      for expectation in expectations where expectation.matches(request) {
        expectation.recordCall(for: request)
        firstMatch = firstMatch ?? expectation
      }

      return firstMatch
    }

    guard let expectation = matchingExpectation else {
      throw HTTPError(category: .network(.connectionLost), request: request)
    }

    return expectation
  }
}
