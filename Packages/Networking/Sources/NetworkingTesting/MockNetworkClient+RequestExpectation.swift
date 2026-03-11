import NetworkingRuntime
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension MockNetworkClient {
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
