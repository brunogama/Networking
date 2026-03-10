// swiftlint:disable file_length
import NetworkingRuntime
import NetworkingInterceptorsCompat
import NetworkingObservability
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct MockURLRequestPredicate: Sendable {
  private let evaluator: @Sendable (URLRequest) -> MockPredicateMatchFlag

  public init(_ evaluator: @escaping @Sendable (URLRequest) -> MockPredicateMatchFlag) {
    self.evaluator = evaluator
  }

  func matches(_ request: URLRequest) -> Bool {
    evaluator(request).rawValue
  }
}

// Advanced URLProtocol-based mock for comprehensive request/response simulation in tests.
//
// This mock protocol provides:
// - Response stubbing with flexible matching
// - Error simulation with network conditions
// - Request verification and capture
// - Streaming response simulation
// - Performance testing with delays
// - Thread-safe operation for concurrent testing
//
// Usage Example:
// MockURLProtocol.stub(
//   matching: .url("https://api.example.com/users/123"),
//   response: .success(statusCode: 200, data: userData)
// )
//
// let config = URLSessionConfiguration.ephemeral
// config.protocolClasses = [MockURLProtocol.self]
// let client = HTTPClient(session: URLSession(configuration: config))
// let response = try await client.execute(request)
//
// `@unchecked Sendable` justification:
// 1. URLProtocol is not Sendable-aware (Apple framework constraint)
// 2. Required for URLSession configuration and request interception
// 3. Static state protected by actor isolation (`MockState` actor)
// 4. URLProtocol callbacks come from URLSession's internal queue (Apple manages threading)
// 5. Test-only code with explicit synchronization in test setup
// swiftlint:disable:next type_body_length
public final class MockURLProtocol: URLProtocol, @unchecked Sendable {
  private static let contextHeader = "X-Networking-Mock-Context"

  // MARK: - Types

  /// Request matching criteria for flexible stub configuration
  public enum RequestMatcher: Sendable {
    case url(HTTPRequestURL)
    case urlPattern(NSRegularExpression)
    case method(HTTPMethod)
    case path(MockRequestPath)
    case header(name: HTTPHeaderName, value: HTTPHeaderValue?)
    case body(HTTPBody)
    case custom(MockURLRequestPredicate)

    // swiftlint:disable:next cyclomatic_complexity
    func matches(_ request: URLRequest) -> Bool {
      switch self {
      case .url(let url):
        return MockURLRequestMatcherSupport.matches(request, url: url)

      case .urlPattern(let regex):
        return MockURLRequestMatcherSupport.matches(request, regex: regex)

      case .method(let httpMethod):
        return MockURLRequestMatcherSupport.matches(request, method: httpMethod)

      case .path(let path):
        return request.url?.path == path.rawValue

      case .header(let name, let value):
        return MockURLRequestMatcherSupport.matches(request, header: name, value: value)

      case .body(let expectedBody):
        return MockURLRequestMatcherSupport.matches(request, body: expectedBody)

      case .custom(let matcher):
        return matcher.matches(request)
      }
    }

    var description: String {
      switch self {
      case .method(let method): return MockURLRequestMatcherSupport.describe(method: method)
      case .url(let url): return MockURLRequestMatcherSupport.describe(url: url)
      case .urlPattern:
        return "urlPattern(regex)"
      case .path(let path): return MockURLRequestMatcherSupport.describe(path: path)
      case .header(let name, let value):
        return MockURLRequestMatcherSupport.describe(header: name, value: value)
      case .body(let body): return MockURLRequestMatcherSupport.describe(body: body)
      case .custom: return "custom matcher"
      }
    }

    public static func urlPattern(_ pattern: RequestPathPattern) -> Self {
      do {
        return .urlPattern(try NSRegularExpression(pattern: pattern.rawValue, options: []))
      } catch {
        return .custom(MockURLRequestPredicate { _ in false })
      }
    }
  }

  /// Mock response configuration
  public enum MockResponse: Sendable {
    case success(statusCode: HTTPStatusCode, data: HTTPBody, headers: HTTPHeaders = [:])
    case failure(Error)
    case timeout
    case networkUnavailable
    case custom(
      statusCode: HTTPStatusCode,
      data: HTTPBody,
      headers: HTTPHeaders,
      delay: MockResponseDelay
    )

    var statusCode: HTTPStatusCode {
      switch self {
      case .success(let code, _, _): return code
      case .custom(let code, _, _, _): return code
      case .failure, .timeout, .networkUnavailable: return -1
      }
    }

    var data: HTTPBody {
      switch self {
      case .success(_, let data, _): return data
      case .custom(_, let data, _, _): return data
      case .failure, .timeout, .networkUnavailable: return HTTPBody(Data())
      }
    }

    var headers: HTTPHeaders {
      switch self {
      case .success(_, _, let headers): return headers
      case .custom(_, _, let headers, _): return headers
      case .failure, .timeout, .networkUnavailable: return [:]
      }
    }

    var delay: MockResponseDelay {
      switch self {
      case .custom(_, _, _, let delay): return delay
      case .timeout: return 0.0  // Fail immediately so timeout simulations do not stall test suites
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
    let maxUsageCount: MockVerificationCount?
    let requestCapture: (@Sendable (URLRequest) -> Void)?
    let contextID: MockContextIdentifier?

    // Internal to allow MockState to update
    internal var usageCount: MockVerificationCount = 0

    public init(
      matchers: [RequestMatcher],
      response: MockResponse,
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

    mutating func incrementUsage() -> Bool {
      // swiftlint:disable:next shorthand_operator
      usageCount = usageCount + 1
      return maxUsageCount.map { usageCount <= $0 } ?? true
    }

    func matches(_ request: URLRequest) -> Bool {
      if let contextID,
        request.value(forHTTPHeaderField: MockURLProtocol.contextHeader) != contextID.uuidString
      {
        return false
      }
      return matchers.allSatisfy { $0.matches(request) }
    }
  }

  // MARK: - State Management

  /// Thread-safe state management for mock protocol
  private actor MockState {
    private var stubs: [RequestStub] = []
    private var capturedRequests: [URLRequest] = []

    func addStub(_ stub: RequestStub) {
      stubs.append(stub)
    }

    /// Get current stub count for testing/debugging
    func getStubCount() -> MockVerificationCount {
      MockVerificationCount(stubs.count)
    }

    func findMatchingStub(for request: URLRequest) -> (RequestStub?, Int?) {
      for (index, stub) in stubs.enumerated() where stub.matches(request) {
        return (stub, index)
      }
      return (nil, nil)
    }

    /// Find and consume a matching stub atomically
    /// - Parameter request: The request to match
    /// - Returns: The matching stub if found (already removed if maxUsageCount reached)
    func findAndConsumeStub(for request: URLRequest) -> RequestStub? {
      for (index, stub) in stubs.enumerated() where stub.matches(request) {
        // Copy the result BEFORE incrementing (to return original state)
        let result = stubs[index]
        // Increment usage count
        // swiftlint:disable:next shorthand_operator
        stubs[index].usageCount = stubs[index].usageCount + 1
        // Remove stub if it reached max usage
        if let maxCount = stub.maxUsageCount, stubs[index].usageCount >= maxCount {
          stubs.remove(at: index)
        }
        return result
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
      // swiftlint:disable:next shorthand_operator
      stubs[index].usageCount = stubs[index].usageCount + 1
      // Remove stub AFTER it's been used maxUsageCount times
      // With maxUsageCount=1, remove after first use (usageCount=1 >= 1)
      if let maxCount = stubs[index].maxUsageCount, stubs[index].usageCount >= maxCount {
        stubs.remove(at: index)
        return false
      }
      return true
    }

    func captureRequest(_ request: URLRequest) {
      capturedRequests.append(request)
    }

    func getCapturedRequests(contextID: MockContextIdentifier?) -> [URLRequest] {
      capturedRequests
        .filter { MockURLProtocol.request($0, matchesContextID: contextID) }
        .map(MockURLProtocol.sanitizedRequest)
    }

    func getRequestCount(
      for url: HTTPRequestURL,
      contextID: MockContextIdentifier?
    ) -> MockVerificationCount {
      MockVerificationCount(
        capturedRequests.filter { request in
          request.url == url.rawValue
            && MockURLProtocol.request(request, matchesContextID: contextID)
        }.count
      )
    }

    func clearAll(contextID: MockContextIdentifier?) {
      guard let contextID else {
        stubs.removeAll()
        capturedRequests.removeAll()
        return
      }

      stubs.removeAll { $0.contextID == contextID }
      capturedRequests.removeAll {
        MockURLProtocol.request($0, matchesContextID: contextID)
      }
    }
  }

  private static let mockState = MockState()

  private static func request(
    _ request: URLRequest,
    matchesContextID contextID: MockContextIdentifier?
  ) -> Bool {
    guard let contextID else { return true }
    return request.value(forHTTPHeaderField: contextHeader) == contextID.uuidString
  }

  private static func sanitizedRequest(_ request: URLRequest) -> URLRequest {
    var request = request
    request.setValue(nil, forHTTPHeaderField: contextHeader)
    return request
  }

  // MARK: - URLProtocol Implementation

  // swiftlint:disable:next static_over_final_class
  override public class func canInit(with request: URLRequest) -> Bool {
    // Only handle requests that have matching stubs
    Task { @Sendable in
      let (stub, _) = await mockState.findMatchingStub(for: request)
      return stub != nil
    }

    // Synchronous fallback - accept all requests and handle in startLoading
    return true
  }

  // swiftlint:disable:next static_over_final_class
  override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  // swiftlint:disable:next function_body_length
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
        wrapper.client?.urlProtocol(
          wrapper.protocolInstance,
          didFailWithError: URLError(.fileDoesNotExist)
        )
        return
      }

      // Execute request capture callback
      stub.requestCapture?(capturedRequest)

      // Apply delay if specified
      let delay = stub.response.delay
      if delay.rawValue > 0 {
        try? await Task.sleep(for: .seconds(delay.rawValue))
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
        statusCode: stub.response.statusCode.rawValue,
        httpVersion: "HTTP/1.1",
        headerFields: stub.response.headers.rawValue
      )!

      wrapper.client?.urlProtocol(
        wrapper.protocolInstance,
        didReceive: httpResponse,
        cacheStoragePolicy: .notAllowed
      )

      // Always call didLoad, even for empty data to match original behavior
      wrapper.client?.urlProtocol(wrapper.protocolInstance, didLoad: stub.response.data.rawValue)

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
    maxUsageCount: MockVerificationCount? = nil,
    requestCapture: (@Sendable (URLRequest) -> Void)? = nil,
    contextID: MockContextIdentifier? = nil
  ) {
    let stub = RequestStub(
      matchers: matchers,
      response: response,
      maxUsageCount: maxUsageCount,
      requestCapture: requestCapture,
      contextID: contextID
    )

    // Use synchronous-style registration with semaphore for reliable test setup
    // Note: Using detached task with high priority to avoid priority inversion
    // that can cause semaphore timeouts in CI environments
    let semaphore = DispatchSemaphore(value: 0)
    Task.detached(priority: .userInitiated) { @Sendable in
      await mockState.addStub(stub)
      semaphore.signal()
    }
    // Wait with longer timeout (30s) for CI environments with resource constraints
    // Use indefinite wait since stub registration must complete for tests to work
    semaphore.wait()
  }

  /// Stub a simple URL with success response
  /// - Parameters:
  ///   - url: The URL to match
  ///   - statusCode: HTTP status code (default: 200)
  ///   - data: Response data
  ///   - headers: Response headers
  ///   - delay: Response delay in seconds
  public static func stubSuccess(
    url: HTTPRequestURL,
    statusCode: HTTPStatusCode = 200,
    data: HTTPBody = HTTPBody(Data()),
    headers: HTTPHeaders = [:],
    delay: MockResponseDelay = 0,
    contextID: MockContextIdentifier? = nil
  ) {
    let response: MockResponse =
      delay.rawValue > 0
      ? .custom(statusCode: statusCode, data: data, headers: headers, delay: delay)
      : .success(statusCode: statusCode, data: data, headers: headers)

    stub(matching: .url(url), response: response, contextID: contextID)
  }

  /// Stub a URL with JSON response
  /// - Parameters:
  ///   - url: The URL to match
  ///   - json: Encodable object to return as JSON
  ///   - statusCode: HTTP status code (default: 200)
  ///   - delay: Response delay in seconds
  public static func stubJSON<T: Encodable>(
    url: HTTPRequestURL,
    json: T,
    statusCode: HTTPStatusCode = 200,
    delay: MockResponseDelay = 0,
    contextID: MockContextIdentifier? = nil
  ) throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(json)
    let headers: HTTPHeaders = ["Content-Type": "application/json"]

    let response: MockResponse =
      delay.rawValue > 0
      ? .custom(statusCode: statusCode, data: HTTPBody(data), headers: headers, delay: delay)
      : .success(statusCode: statusCode, data: HTTPBody(data), headers: headers)

    stub(matching: .url(url), response: response, contextID: contextID)
  }

  /// Stub a URL with error response
  /// - Parameters:
  ///   - url: The URL to match
  ///   - error: The error to throw
  public static func stubError(
    url: HTTPRequestURL,
    error: Error,
    contextID: MockContextIdentifier? = nil
  ) {
    stub(matching: .url(url), response: .failure(error), contextID: contextID)
  }

  /// Stub a URL with timeout
  /// - Parameter url: The URL to match
  public static func stubTimeout(url: HTTPRequestURL, contextID: MockContextIdentifier? = nil) {
    stub(matching: .url(url), response: .timeout, contextID: contextID)
  }

  /// Stub a URL pattern with regex matching
  /// - Parameters:
  ///   - pattern: Regular expression pattern to match URLs
  ///   - response: The mock response to return
  public static func stubPattern(
    _ pattern: MockURLPattern,
    response: MockResponse,
    contextID: MockContextIdentifier? = nil
  ) throws {
    let regex = try NSRegularExpression(pattern: pattern.rawValue, options: [])
    stub(matching: .urlPattern(regex), response: response, contextID: contextID)
  }

  // MARK: - Verification and Inspection

  /// Get all captured requests
  /// - Returns: Array of all requests that were handled by the mock
  public static func getCapturedRequests(
    contextID: MockContextIdentifier? = nil
  ) async -> [URLRequest] {
    await mockState.getCapturedRequests(contextID: contextID)
  }

  /// Get request count for a specific URL
  /// - Parameter url: The URL to check
  /// - Returns: Number of times requests were made to this URL
  public static func getRequestCount(
    for url: HTTPRequestURL,
    contextID: MockContextIdentifier? = nil
  ) async -> MockVerificationCount {
    await mockState.getRequestCount(for: url, contextID: contextID)
  }

  /// Verify that a request was made
  /// - Parameters:
  ///   - url: The URL that should have been requested
  ///   - method: Optional HTTP method to verify
  ///   - count: Expected number of requests (default: at least 1)
  /// - Returns: True if verification passes
  public static func verifyRequest(
    url: HTTPRequestURL,
    method: HTTPMethod? = nil,
    count: MockVerificationCount = 1,
    contextID: MockContextIdentifier? = nil
  ) async -> MockPredicateMatchFlag {
    let requests = await getCapturedRequests(contextID: contextID)
    let matchingRequests = requests.filter { request in
      let urlMatches = request.url == url.rawValue
      let methodMatches =
        method.map { request.httpMethod?.uppercased() == $0.rawValue.uppercased() } ?? true
      return urlMatches && methodMatches
    }
    return MockPredicateMatchFlag(matchingRequests.count >= count.rawValue)
  }

  /// Clear all stubs and captured requests
  public static func clearAll(contextID: MockContextIdentifier? = nil) {
    let semaphore = DispatchSemaphore(value: 0)
    Task.detached(priority: .userInitiated) { @Sendable in
      await mockState.clearAll(contextID: contextID)
      semaphore.signal()
    }
    // Use indefinite wait since clear must complete for reliable test isolation
    semaphore.wait()
  }

  /// Get current stub count for testing/debugging
  public static func getStubCount() async -> MockVerificationCount {
    await mockState.getStubCount()
  }

  // MARK: - Convenience Methods

  /// Create a URLSessionConfiguration configured with MockURLProtocol
  /// - Returns: URLSessionConfiguration ready for testing
  public static func createMockConfiguration(
    contextID: MockContextIdentifier? = nil
  ) -> URLSessionConfiguration {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    if let contextID {
      var headers = config.httpAdditionalHeaders ?? [:]
      headers[contextHeader] = contextID.uuidString
      config.httpAdditionalHeaders = headers
    }
    // Disable caching to ensure fresh responses for each request
    config.urlCache = nil
    config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    return config
  }

  /// Create an HTTPClient configured with MockURLProtocol
  /// - Returns: HTTPClient instance ready for testing
  public static func createMockHTTPClient(contextID: MockContextIdentifier? = nil) -> HTTPClient {
    let config = createMockConfiguration(contextID: contextID)
    return NetworkClient(session: URLSession(configuration: config))
  }
}

// MARK: - Testing Extensions

extension MockURLProtocol {
  /// Stub multiple URLs with the same response
  /// - Parameters:
  ///   - urls: Array of URLs to stub
  ///   - response: The mock response for all URLs
  public static func stubMultiple(
    urls: [HTTPRequestURL],
    response: MockResponse,
    contextID: MockContextIdentifier? = nil
  ) {
    for url in urls {
      stub(matching: .url(url), response: response, contextID: contextID)
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
    baseURL: HTTPRequestURL,
    path: MockRequestPath,
    getResponse: MockResponse? = nil,
    postResponse: MockResponse? = nil,
    putResponse: MockResponse? = nil,
    deleteResponse: MockResponse? = nil,
    contextID: MockContextIdentifier? = nil
  ) {
    let fullURLString =
      baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      + path.rawValue
    let fullURL = HTTPRequestURL(URL(string: fullURLString)!)

    if let response = getResponse {
      stub(matching: .url(fullURL), .method(.get), response: response, contextID: contextID)
    }
    if let response = postResponse {
      stub(matching: .url(fullURL), .method(.post), response: response, contextID: contextID)
    }
    if let response = putResponse {
      stub(matching: .url(fullURL), .method(.put), response: response, contextID: contextID)
    }
    if let response = deleteResponse {
      stub(matching: .url(fullURL), .method(.delete), response: response, contextID: contextID)
    }
  }

  /// Stub with sequential responses (different response for each call)
  /// - Parameters:
  ///   - url: The URL to match
  ///   - responses: Array of responses to return in sequence
  public static func stubSequential(
    url: HTTPRequestURL,
    responses: [MockResponse],
    contextID: MockContextIdentifier? = nil
  ) {
    for response in responses {
      stub(
        matching: .url(url),
        response: response,
        maxUsageCount: 1,
        contextID: contextID
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
    url: HTTPRequestURL,
    method: HTTPMethod? = nil,
    count: MockVerificationCount = 1,
    contextID: MockContextIdentifier? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async {
    let verified = await verifyRequest(url: url, method: method, count: count, contextID: contextID)
    #expect(
      verified.rawValue,
      "Expected \(count) request(s) to \(url.absoluteString), but verification failed",
      sourceLocation: sourceLocation
    )
  }

  /// Assert that no requests were made to a URL
  /// - Parameters:
  ///   - url: The URL that should not have been requested
  ///   - file: Source file for error reporting
  ///   - line: Source line for error reporting
  public static func expectNoRequest(
    url: HTTPRequestURL,
    contextID: MockContextIdentifier? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async {
    let count = await getRequestCount(for: url, contextID: contextID)
    #expect(
      count == 0,
      "Expected no requests to \(url.absoluteString), but found \(count)",
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
    if case .timeout = self {
      throw HTTPError(
        category: .timeout,
        request: request,
        underlyingError: URLError(.timedOut)
      )
    }

    // Apply delay if configured
    if delay.rawValue > 0 {
      try await Task.sleep(nanoseconds: UInt64(delay.rawValue * 1_000_000_000))
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
