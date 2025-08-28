import Foundation

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

    private var _usageCount = 0

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

    func findMatchingStub(for request: URLRequest) -> (RequestStub?, Int?) {
      for (index, stub) in stubs.enumerated() {
        if stub.matches(request) {
          return (stub, index)
        }
      }
      return (nil, nil)
    }

    func removeStub(at index: Int) {
      guard index < stubs.count else { return }
      stubs.remove(at: index)
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
    Task {
      await handleRequest()
    }
  }

  override public func stopLoading() {
    // No cleanup needed for our async implementation
  }

  // MARK: - Request Handling

  private func handleRequest() async {
    await Self.mockState.captureRequest(request)

    let (stub, stubIndex) = await Self.mockState.findMatchingStub(for: request)

    guard let stub = stub else {
      client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
      return
    }

    // Handle usage count
    if let stubIndex = stubIndex {
      var mutableStub = stub
      if !mutableStub.incrementUsage() {
        await Self.mockState.removeStub(at: stubIndex)
      }
    }

    // Execute request capture callback
    stub.requestCapture?(request)

    // Apply delay if specified
    let delay = stub.response.delay
    if delay > 0 {
      try? await Task.sleep(for: .seconds(delay))
    }

    // Handle response based on type
    if let error = stub.response.error {
      client?.urlProtocol(self, didFailWithError: error)
      return
    }

    // Create successful response
    guard let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }

    let httpResponse = HTTPURLResponse(
      url: url,
      statusCode: stub.response.statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: stub.response.headers
    )!

    client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: stub.response.data)
    client?.urlProtocolDidFinishLoading(self)
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

    Task { @Sendable in
      await mockState.addStub(stub)
    }
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
    Task { @Sendable in
      await mockState.clearAll()
    }
  }

  // MARK: - Convenience Methods

  /// Create a URLSessionConfiguration configured with MockURLProtocol
  /// - Returns: URLSessionConfiguration ready for testing
  public static func createMockConfiguration() -> URLSessionConfiguration {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
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
