import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Advanced URLProtocol-based mock for comprehensive request/response simulation in tests
///
/// This mock protocol provides:
/// - Response stubbing with flexible matching
/// - Error simulation with network conditions
/// - Request verification and capture
/// - Streaming response simulation
/// - Performance testing with delays
/// - Thread-safe operation for concurrent testing
///
/// ## Usage Example
/// ```swift
/// // Setup mock responses
/// MockURLProtocol.stub(
///   matching: .url("https://api.example.com/users/123"),
///   response: .success(statusCode: 200, data: userData)
/// )
///
/// // Configure URLSession with mock
/// let config = URLSessionConfiguration.ephemeral
/// config.protocolClasses = [MockURLProtocol.self]
/// let client = HTTPClient(session: URLSession(configuration: config))
///
/// // Execute test
/// let response = try await client.execute(request)
/// ```
///
/// - Note: `@unchecked Sendable` justification:
///   1. URLProtocol is not Sendable-aware (Apple framework constraint)
///   2. Required for URLSession configuration and request interception
///   3. Static state protected by actor isolation (`MockState` actor)
///   4. URLProtocol callbacks come from URLSession's internal queue (Apple manages threading)
///   5. Test-only code with explicit synchronization in test setup
public final class MockURLProtocol: URLProtocol, @unchecked Sendable {
  // MARK: - Types

  /// Request matching criteria for flexible stub configuration
  public enum RequestMatcher: Sendable {
    case url(String)
    case urlPattern(NSRegularExpression)
    case method(HTTPMethod)
    case header(name: String, value: String)
    case body(Data)
    case custom(@Sendable (URLRequest) -> Bool)

    public func matches(_ request: URLRequest) -> Bool {
      switch self {
      case .url(let urlString):
        return request.url?.absoluteString == urlString

      case .urlPattern(let regex):
        guard let url = request.url?.absoluteString else { return false }
        return regex.firstMatch(in: url, range: NSRange(location: 0, length: url.count)) != nil

      case .method(let httpMethod):
        return request.httpMethod?.uppercased() == httpMethod.rawValue.uppercased()

      case .header(let name, let value):
        return request.value(forHTTPHeaderField: name) == value

      case .body(let expectedBody):
        return request.httpBody == expectedBody

      case .custom(let matcher):
        return matcher(request)
      }
    }
  }

  /// Mock response configuration
  public enum MockResponse: Sendable {
    case success(statusCode: Int, data: Data, headers: [String: String] = [:])
    case failure(Error)
    case timeout
    case networkUnavailable
    case custom(statusCode: Int, data: Data, headers: [String: String], delay: TimeInterval)

    var statusCode: Int {
      switch self {
      case .success(let code, _, _): return code
      case .custom(let code, _, _, _): return code
      case .failure, .timeout, .networkUnavailable: return -1
      }
    }

    var data: Data {
      switch self {
      case .success(_, let data, _): return data
      case .custom(_, let data, _, _): return data
      case .failure, .timeout, .networkUnavailable: return Data()
      }
    }

    var headers: [String: String] {
      switch self {
      case .success(_, _, let headers): return headers
      case .custom(_, _, let headers, _): return headers
      case .failure, .timeout, .networkUnavailable: return [:]
      }
    }

    var delay: TimeInterval {
      switch self {
      case .custom(_, _, _, let delay): return delay
      case .timeout: return 60.0  // Simulate long timeout
      default: return 0.0
      }
    }

    var error: Error? {
      switch self {
      case .failure(let error): return error
      case .timeout: return URLError(.timedOut)
      case .networkUnavailable: return URLError(.notConnectedToInternet)
      default: return nil
      }
    }
  }

  /// Request stub configuration
  public struct RequestStub: Sendable {
    let matchers: [RequestMatcher]
    let response: MockResponse
    let maxUsageCount: Int?
    let requestCapture: (@Sendable (URLRequest) -> Void)?

    // Internal to allow MockState to update
    internal var _usageCount = 0

    public init(
      matchers: [RequestMatcher],
      response: MockResponse,
      maxUsageCount: Int? = nil,
      requestCapture: (@Sendable (URLRequest) -> Void)? = nil,
      _usageCount: Int = 0
    ) {
      self.matchers = matchers
      self.response = response
      self.maxUsageCount = maxUsageCount
      self.requestCapture = requestCapture
      self._usageCount = _usageCount
    }

    mutating func incrementUsage() -> Bool {
      _usageCount += 1
      return maxUsageCount.map { _usageCount <= $0 } ?? true
    }

    func matches(_ request: URLRequest) -> Bool {
      matchers.allSatisfy { $0.matches(request) }
    }
  }

  // MARK: - State Management

  /// Thread-safe state management for mock protocol
  private actor MockState {
    private var stubs: [RequestStub] = []
    private var capturedRequests: [URLRequest] = []
    private var requestCount: [String: Int] = [:]

    func addStub(_ stub: RequestStub) {
      stubs.append(stub)
    }

    /// Get current stub count for testing/debugging
    func getStubCount() -> Int {
      stubs.count
    }

    func findMatchingStub(for request: URLRequest) -> (RequestStub?, Int?) {
      for (index, stub) in stubs.enumerated() {
        if stub.matches(request) {
          return (stub, index)
        }
      }
      return (nil, nil)
    }

    /// Find and consume a matching stub atomically
    /// - Parameter request: The request to match
    /// - Returns: The matching stub if found (already removed if maxUsageCount reached)
    func findAndConsumeStub(for request: URLRequest) -> RequestStub? {
      for (index, stub) in stubs.enumerated() {
        if stub.matches(request) {
          // Copy the result BEFORE incrementing (to return original state)
          let result = stubs[index]
          // Increment usage count
          stubs[index]._usageCount += 1
          // Remove stub if it reached max usage
          if let maxCount = stub.maxUsageCount, stubs[index]._usageCount >= maxCount {
            stubs.remove(at: index)
          }
          return result
        }
      }
      return nil
    }

    func removeStub(at index: Int) {
      guard index < stubs.count else { return }
      stubs.remove(at: index)
    }

    /// Increment stub usage and remove if exhausted
    /// - Parameter index: Index of the stub
    /// - Returns: true if stub should be kept, false if exhausted and removed
    func incrementStubUsage(at index: Int) -> Bool {
      guard index < stubs.count else { return false }
      stubs[index]._usageCount += 1
      // Remove stub AFTER it's been used maxUsageCount times
      // With maxUsageCount=1, remove after first use (usageCount=1 >= 1)
      if let maxCount = stubs[index].maxUsageCount, stubs[index]._usageCount >= maxCount {
        stubs.remove(at: index)
        return false
      }
      return true
    }

    func captureRequest(_ request: URLRequest) {
      capturedRequests.append(request)

      let key = request.url?.absoluteString ?? "unknown"
      requestCount[key, default: 0] += 1
    }

    func getCapturedRequests() -> [URLRequest] {
      capturedRequests
    }

    func getRequestCount(for urlString: String) -> Int {
      requestCount[urlString, default: 0]
    }

    func clearAll() {
      stubs.removeAll()
      capturedRequests.removeAll()
      requestCount.removeAll()
    }
  }

  private static let mockState = MockState()

  // MARK: - URLProtocol Implementation

  override public class func canInit(with request: URLRequest) -> Bool {
    // Only handle requests that have matching stubs
    Task { @Sendable in
      let (stub, _) = await mockState.findMatchingStub(for: request)
      return stub != nil
    }

    // Synchronous fallback - accept all requests and handle in startLoading
    return true
  }

  override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override public func startLoading() {
    // We need to work around Swift concurrency's strict sendability checks
    // Since URLProtocol is designed for synchronous URL loading subsystem,
    // but we're using async/await, we need to use @unchecked Sendable workaround
    let capturedRequest = request
    let capturedClient = client

    /// Wrapper to send URLProtocol instance across concurrency boundaries.
    ///
    /// - Note: `@unchecked Sendable` justification:
    ///   1. Bridges non-Sendable URLProtocol API to async/await Task
    ///   2. Instance captured at single point, used in single Task
    ///   3. URLProtocolClient managed by URLSession (thread-safe)
    ///   4. No actual concurrent access - sequential use in Task closure
    struct UnsafeWrapper: @unchecked Sendable {
      let protocolInstance: MockURLProtocol
      let client: URLProtocolClient?
    }
    let wrapper = UnsafeWrapper(protocolInstance: self, client: capturedClient)

    Task { @Sendable in
      await Self.mockState.captureRequest(capturedRequest)

      // Find and consume stub atomically to prevent race conditions
      guard let stub = await Self.mockState.findAndConsumeStub(for: capturedRequest) else {
        wrapper.client?.urlProtocol(wrapper.protocolInstance, didFailWithError: URLError(.fileDoesNotExist))
        return
      }

      // Execute request capture callback
      stub.requestCapture?(capturedRequest)
      
      // Apply delay if specified
      let delay = stub.response.delay
      if delay > 0 {
        try? await Task.sleep(for: .seconds(delay))
      }
      
      // Handle response based on type
      if let error = stub.response.error {
        wrapper.client?.urlProtocol(wrapper.protocolInstance, didFailWithError: error)
        return
      }
      
      // Create successful response
      guard let url = capturedRequest.url else {
        wrapper.client?.urlProtocol(wrapper.protocolInstance, didFailWithError: URLError(.badURL))
        return
      }
      
      let httpResponse = HTTPURLResponse(
        url: url,
        statusCode: stub.response.statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: stub.response.headers
      )!
      
      wrapper.client?.urlProtocol(wrapper.protocolInstance, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
      
      // Always call didLoad, even for empty data to match original behavior
      wrapper.client?.urlProtocol(wrapper.protocolInstance, didLoad: stub.response.data)
      
      wrapper.client?.urlProtocolDidFinishLoading(wrapper.protocolInstance)
    }
  }

  override public func stopLoading() {
    // No cleanup needed for our async implementation
  }

  // MARK: - Public API

  /// Stub a request with flexible matching criteria
  /// - Parameters:
  ///   - matchers: Array of matchers that must all match for the stub to be used
  ///   - response: The mock response to return
  ///   - maxUsageCount: Maximum number of times this stub can be used (nil = unlimited)
  ///   - requestCapture: Optional closure to capture and inspect the request
  public static func stub(
    matching matchers: RequestMatcher...,
    response: MockResponse,
    maxUsageCount: Int? = nil,
    requestCapture: (@Sendable (URLRequest) -> Void)? = nil
  ) {
    let stub = RequestStub(
      matchers: matchers,
      response: response,
      maxUsageCount: maxUsageCount,
      requestCapture: requestCapture
    )

    // Use synchronous-style registration with semaphore for reliable test setup
    let semaphore = DispatchSemaphore(value: 0)
    Task { @Sendable in
      await mockState.addStub(stub)
      semaphore.signal()
    }
    // Wait briefly to ensure stub is registered before test continues
    _ = semaphore.wait(timeout: .now() + 1.0)
  }

  /// Stub a simple URL with success response
  /// - Parameters:
  ///   - url: The URL to match
  ///   - statusCode: HTTP status code (default: 200)
  ///   - data: Response data
  ///   - headers: Response headers
  ///   - delay: Response delay in seconds
  public static func stubSuccess(
    url: String,
    statusCode: Int = 200,
    data: Data = Data(),
    headers: [String: String] = [:],
    delay: TimeInterval = 0
  ) {
    let response: MockResponse =
      delay > 0
      ? .custom(statusCode: statusCode, data: data, headers: headers, delay: delay)
      : .success(statusCode: statusCode, data: data, headers: headers)

    stub(matching: .url(url), response: response)
  }

  /// Stub a URL with JSON response
  /// - Parameters:
  ///   - url: The URL to match
  ///   - json: Encodable object to return as JSON
  ///   - statusCode: HTTP status code (default: 200)
  ///   - delay: Response delay in seconds
  public static func stubJSON<T: Encodable>(
    url: String,
    json: T,
    statusCode: Int = 200,
    delay: TimeInterval = 0
  ) throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(json)
    let headers = ["Content-Type": "application/json"]

    let response: MockResponse =
      delay > 0
      ? .custom(statusCode: statusCode, data: data, headers: headers, delay: delay)
      : .success(statusCode: statusCode, data: data, headers: headers)

    stub(matching: .url(url), response: response)
  }

  /// Stub a URL with error response
  /// - Parameters:
  ///   - url: The URL to match
  ///   - error: The error to throw
  public static func stubError(url: String, error: Error) {
    stub(matching: .url(url), response: .failure(error))
  }

  /// Stub a URL with timeout
  /// - Parameter url: The URL to match
  public static func stubTimeout(url: String) {
    stub(matching: .url(url), response: .timeout)
  }

  /// Stub a URL pattern with regex matching
  /// - Parameters:
  ///   - pattern: Regular expression pattern to match URLs
  ///   - response: The mock response to return
  public static func stubPattern(_ pattern: String, response: MockResponse) throws {
    let regex = try NSRegularExpression(pattern: pattern, options: [])
    stub(matching: .urlPattern(regex), response: response)
  }

  // MARK: - Verification and Inspection

  /// Get all captured requests
  /// - Returns: Array of all requests that were handled by the mock
  public static func getCapturedRequests() async -> [URLRequest] {
    await mockState.getCapturedRequests()
  }

  /// Get request count for a specific URL
  /// - Parameter url: The URL to check
  /// - Returns: Number of times requests were made to this URL
  public static func getRequestCount(for url: String) async -> Int {
    await mockState.getRequestCount(for: url)
  }

  /// Verify that a request was made
  /// - Parameters:
  ///   - url: The URL that should have been requested
  ///   - method: Optional HTTP method to verify
  ///   - count: Expected number of requests (default: at least 1)
  /// - Returns: True if verification passes
  public static func verifyRequest(
    url: String,
    method: HTTPMethod? = nil,
    count: Int = 1
  ) async -> Bool {
    let requests = await getCapturedRequests()
    let matchingRequests = requests.filter { request in
      let urlMatches = request.url?.absoluteString == url
      let methodMatches =
        method.map { request.httpMethod?.uppercased() == $0.rawValue.uppercased() } ?? true
      return urlMatches && methodMatches
    }
    return matchingRequests.count >= count
  }

  /// Clear all stubs and captured requests
  public static func clearAll() {
    let semaphore = DispatchSemaphore(value: 0)
    Task { @Sendable in
      await mockState.clearAll()
      semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 1.0)
  }

  /// Get current stub count for testing/debugging
  public static func getStubCount() async -> Int {
    await mockState.getStubCount()
  }

  // MARK: - Convenience Methods

  /// Create a URLSessionConfiguration configured with MockURLProtocol
  /// - Returns: URLSessionConfiguration ready for testing
  public static func createMockConfiguration() -> URLSessionConfiguration {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    // Disable caching to ensure fresh responses for each request
    config.urlCache = nil
    config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    return config
  }

  /// Create an HTTPClient configured with MockURLProtocol
  /// - Returns: HTTPClient instance ready for testing
  public static func createMockHTTPClient() -> HTTPClient {
    let config = createMockConfiguration()
    return NetworkClient(session: URLSession(configuration: config))
  }
}

// MARK: - Testing Extensions

extension MockURLProtocol {
  /// Stub multiple URLs with the same response
  /// - Parameters:
  ///   - urls: Array of URLs to stub
  ///   - response: The mock response for all URLs
  public static func stubMultiple(urls: [String], response: MockResponse) {
    for url in urls {
      stub(matching: .url(url), response: response)
    }
  }

  /// Stub a REST API endpoint with different methods
  /// - Parameters:
  ///   - baseURL: Base URL for the endpoint
  ///   - path: Path component
  ///   - getResponse: Response for GET requests
  ///   - postResponse: Response for POST requests
  ///   - putResponse: Response for PUT requests
  ///   - deleteResponse: Response for DELETE requests
  public static func stubRESTEndpoint(
    baseURL: String,
    path: String,
    getResponse: MockResponse? = nil,
    postResponse: MockResponse? = nil,
    putResponse: MockResponse? = nil,
    deleteResponse: MockResponse? = nil
  ) {
    let fullURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path

    if let response = getResponse {
      stub(matching: .url(fullURL), .method(.get), response: response)
    }
    if let response = postResponse {
      stub(matching: .url(fullURL), .method(.post), response: response)
    }
    if let response = putResponse {
      stub(matching: .url(fullURL), .method(.put), response: response)
    }
    if let response = deleteResponse {
      stub(matching: .url(fullURL), .method(.delete), response: response)
    }
  }

  /// Stub with sequential responses (different response for each call)
  /// - Parameters:
  ///   - url: The URL to match
  ///   - responses: Array of responses to return in sequence
  public static func stubSequential(url: String, responses: [MockResponse]) {
    for (_, response) in responses.enumerated() {
      stub(
        matching: .url(url),
        response: response,
        maxUsageCount: 1
      )
    }
  }
}

// MARK: - Swift Testing Integration

#if canImport(Testing)
import Testing

extension MockURLProtocol {
  /// Assert that a request was made with Swift Testing
  /// - Parameters:
  ///   - url: The URL that should have been requested
  ///   - method: Optional HTTP method to verify
  ///   - count: Expected number of requests
  ///   - file: Source file for error reporting
  ///   - line: Source line for error reporting
  public static func expectRequest(
    url: String,
    method: HTTPMethod? = nil,
    count: Int = 1,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async {
    let verified = await verifyRequest(url: url, method: method, count: count)
    #expect(
      verified,
      "Expected \(count) request(s) to \(url), but verification failed",
      sourceLocation: sourceLocation
    )
  }

  /// Assert that no requests were made to a URL
  /// - Parameters:
  ///   - url: The URL that should not have been requested
  ///   - file: Source file for error reporting
  ///   - line: Source line for error reporting
  public static func expectNoRequest(
    url: String,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async {
    let count = await getRequestCount(for: url)
    #expect(
      count == 0,
      "Expected no requests to \(url), but found \(count)",
      sourceLocation: sourceLocation
    )
  }
}

#endif

// MARK: - MockResponse HTTPResponse Conversion

extension MockURLProtocol.MockResponse {
  /// Convert MockResponse to HTTPResponse for use with MockNetworkClient
  /// - Parameter request: The original HTTP request
  /// - Returns: HTTPResponse based on the mock configuration
  /// - Throws: The configured error if this is a failure response
  public func toHTTPResponse(for request: HTTPRequest) async throws -> HTTPResponse {
    // Apply delay if configured
    if delay > 0 {
      try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    // Handle error cases
    if let responseError = error {
      throw HTTPError(
        category: .network(.connectionLost),
        request: request,
        underlyingError: responseError
      )
    }

    // Build successful response
    return HTTPResponse(
      request: request,
      status: HTTPStatus(rawValue: statusCode),
      headers: headers,
      body: data
    )
  }
}
