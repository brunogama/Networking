import NetworkingRuntime
import NetworkingInterceptorsCompat
import NetworkingObservability
import Foundation
// swiftlint:disable file_length

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPRequestPredicate: Sendable {
  private let evaluator: @Sendable (HTTPRequest) -> MockPredicateMatchFlag

  public init(_ evaluator: @escaping @Sendable (HTTPRequest) -> MockPredicateMatchFlag) {
    self.evaluator = evaluator
  }

  func matches(_ request: HTTPRequest) -> Bool {
    evaluator(request).rawValue
  }
}

// swiftlint:disable type_body_length
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

  /// Request expectation with flexible matching and response configuration
  ///
  /// - Note: `@unchecked Sendable` justification:
  ///   1. Test infrastructure only
  ///   2. Mutable state protected by parent `MockNetworkClient`'s concurrent queue with barrier
  ///   3. All mutations synchronized through parent's queue operations
  ///   4. Short-lived during test execution (created, used, verified, discarded)
  public final class RequestExpectation: @unchecked Sendable {
    private let client: MockNetworkClient
    internal var matchers: [RequestMatcher]
    private var response: MockResponse?
    private var expectedCallCount: CallCountExpectation = .atLeastOnce
    private var actualCallCount: Int = 0
    private var requestCapture: (@Sendable (HTTPRequest) -> Void)?
    private var fulfilled: Bool = false

    public typealias CallCountExpectation = MockCallCountExpectation

    internal init(client: MockNetworkClient, matcher: RequestMatcher) {
      self.client = client
      self.matchers = [matcher]
    }

    // MARK: - Response Configuration

    /// Specify the response to return for this expectation
    /// - Parameter response: The mock response configuration
    /// - Returns: Self for method chaining
    @discardableResult
    public func andReturn(_ response: MockResponse) -> Self {
      self.response = response
      return self
    }

    /// Return a successful JSON response
    /// - Parameters:
    ///   - json: Encodable object to return as JSON
    ///   - statusCode: HTTP status code (default: 200)
    /// - Returns: Self for method chaining
    @discardableResult
    public func andReturnJSON<T: Encodable>(
      _ json: T,
      statusCode: HTTPStatusCode = 200
    ) throws -> Self {
      let encoder = JSONEncoder()
      let data = try encoder.encode(json)
      let headers: HTTPHeaders = ["Content-Type": "application/json"]
      return andReturn(.success(statusCode: statusCode, data: HTTPBody(data), headers: headers))
    }

    /// Return an error response
    /// - Parameter error: The error to return
    /// - Returns: Self for method chaining
    @discardableResult
    public func andReturnError(_ error: Error) -> Self {
      andReturn(.failure(error))
    }

    /// Return a timeout
    /// - Returns: Self for method chaining
    @discardableResult
    public func andTimeout() -> Self {
      andReturn(.timeout)
    }

    /// Return response with delay
    /// - Parameters:
    ///   - response: The base response
    ///   - delay: Delay in seconds
    /// - Returns: Self for method chaining
    @discardableResult
    public func andReturn(_ response: MockResponse, withDelay delay: MeasurementDuration) -> Self {
      switch response {
      case .success(let statusCode, let data, let headers):
        return andReturn(
          .custom(
            statusCode: statusCode,
            data: data,
            headers: headers,
            delay: MockResponseDelay(delay.rawValue)
          )
        )

      default:
        return andReturn(response)  // For error cases, delay is handled by MockURLProtocol
      }
    }

    // MARK: - Call Count Expectations

    /// Expect this request to never be called
    /// - Returns: Self for method chaining
    @discardableResult
    public func never() -> Self {
      expectedCallCount = .never
      return self
    }

    /// Expect this request to be called exactly once
    /// - Returns: Self for method chaining
    @discardableResult
    public func once() -> Self {
      expectedCallCount = .once
      return self
    }

    /// Expect this request to be called an exact number of times
    /// - Parameter count: Expected call count
    /// - Returns: Self for method chaining
    @discardableResult
    public func exactly(_ count: RequestCount) -> Self {
      expectedCallCount = .exactly(count)
      return self
    }

    /// Expect this request to be called at least a certain number of times
    /// - Parameter min: Minimum expected call count
    /// - Returns: Self for method chaining
    @discardableResult
    public func atLeast(_ min: RequestCount) -> Self {
      expectedCallCount = .atLeast(min)
      return self
    }

    /// Expect this request to be called at least once
    /// - Returns: Self for method chaining
    @discardableResult
    public func atLeastOnce() -> Self {
      expectedCallCount = .atLeastOnce
      return self
    }

    /// Expect this request to be called at most a certain number of times
    /// - Parameter max: Maximum expected call count
    /// - Returns: Self for method chaining
    @discardableResult
    public func atMost(_ max: RequestCount) -> Self {
      expectedCallCount = .atMost(max)
      return self
    }

    /// Expect this request to be called between min and max times
    /// - Parameters:
    ///   - min: Minimum expected call count
    ///   - max: Maximum expected call count
    /// - Returns: Self for method chaining
    @discardableResult
    public func between(min: RequestCount, max: RequestCount) -> Self {
      expectedCallCount = .between(min: min, max: max)
      return self
    }

    // MARK: - Request Inspection

    /// Capture requests that match this expectation for inspection
    /// - Parameter capture: Closure to handle captured requests
    /// - Returns: Self for method chaining
    @discardableResult
    public func capture(_ capture: @escaping @Sendable (HTTPRequest) -> Void) -> Self {
      self.requestCapture = capture
      return self
    }

    // MARK: - Internal Methods

    internal func matches(_ request: HTTPRequest) -> Bool {
      var urlRequest = URLRequest(url: request.url)
      urlRequest.httpMethod = request.method.rawValue.rawValue
      urlRequest.httpBody = request.body?.rawValue
      for (key, value) in request.headers {
        urlRequest.setValue(value.rawValue, forHTTPHeaderField: key.rawValue)
      }
      // All matchers must match for the expectation to match
      return matchers.allSatisfy { $0.matches(urlRequest) }
    }

    internal func recordCall(for request: HTTPRequest) {
      actualCallCount += 1
      requestCapture?(request)
    }

    internal var isFulfilled: Bool {
      expectedCallCount.matches(actualCallCount)
    }

    internal var expectationDescription: String {
      let matcherDescriptions = matchers.map(\.description).joined(separator: ", ")
      return
        "Expected request matching [\(matcherDescriptions)] to be called \(expectedCallCount.description), but was called \(actualCallCount) time(s)"
    }

    internal var mockResponse: MockResponse {
      response ?? .success(statusCode: 200, data: HTTPBody(Data()))
    }
  }

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
// swiftlint:enable type_body_length

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

// MARK: - RequestExpectation Method Chaining Extensions

extension MockNetworkClient.RequestExpectation {
  /// Add another matcher to this expectation (AND logic)
  /// - Parameter matcher: Additional matcher
  /// - Returns: Self for method chaining
  @discardableResult
  public func expect(_ matcher: MockNetworkClient.RequestMatcher) -> Self {
    matchers.append(matcher)
    return self
  }

  /// Expect a specific header
  /// - Parameters:
  ///   - name: Header name
  ///   - value: Expected header value (nil to just check presence)
  /// - Returns: Self for method chaining
  @discardableResult
  public func withHeader(_ name: HTTPHeaderName, value: HTTPHeaderValue? = nil) -> Self {
    expect(.header(name: name, value: value))
  }

  /// Expect a specific request body
  /// - Parameter body: Expected request body
  /// - Returns: Self for method chaining
  @discardableResult
  public func withBody(_ body: HTTPBody) -> Self {
    expect(.body(body))
  }

  /// Expect a JSON request body
  /// - Parameter json: Encodable object expected in request body
  /// - Returns: Self for method chaining
  @discardableResult
  public func withJSONBody<T: Encodable>(_ json: T) throws -> Self {
    let encoder = JSONEncoder()
    let data = try encoder.encode(json)
    return withBody(HTTPBody(data))
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

// MARK: - Performance Testing Extensions

extension MockNetworkClient {
  /// Measure the performance of a request
  /// - Parameter request: The request to measure
  /// - Returns: Performance metrics
  public func measurePerformance(for request: HTTPRequest) async throws -> PerformanceMetrics {
    let startTime = Date()
    let startMemory = getCurrentMemoryUsage()

    let response = try await execute(request)

    let duration = MeasurementDuration(Date().timeIntervalSince(startTime))
    let endMemory = getCurrentMemoryUsage()

    return PerformanceMetrics(
      duration: duration,
      memoryDelta: StorageSizeValue(endMemory - startMemory),
      responseSize: ResponseSize((response.body?.count ?? 0).rawValue)
    )
  }

  private func getCurrentMemoryUsage() -> Int {
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
      MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    #else
    // On Linux, memory tracking is not available via this method
    return 0
    #endif
  }
}

// MARK: - Performance Metrics

public struct PerformanceMetrics {
  public let duration: MeasurementDuration
  public let memoryDelta: StorageSizeValue
  public let responseSize: ResponseSize

  public var throughput: ThroughputValue {
    guard duration.rawValue > 0 else { return 0 }
    return ThroughputValue(Double(responseSize.rawValue) / duration.rawValue)
  }

  public var description: String {
    """
    Duration: \(String(format: "%.3f", duration.rawValue))s
    Memory Delta: \(memoryDelta.rawValue) bytes
    Response Size: \(responseSize.rawValue) bytes
    Throughput: \(String(format: "%.2f", throughput.rawValue)) bytes/s
    """
  }
}
// swiftlint:enable file_length
