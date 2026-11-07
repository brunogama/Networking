import NetworkingCore

/// Records requests and applies a configured transformation selected before suspension.
public actor MockHTTPRequestMiddleware: HTTPRequestMiddleware, MockVerifiable {
  private var transform: (@Sendable (HTTPRequest) async throws -> HTTPRequest)?
  private var failure: (any Error)?
  private var requests: [HTTPRequest] = []

  /// Creates a middleware that returns requests unchanged.
  public init() {}

  /// Records the request, then applies the current behavior without later state mutation.
  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    requests.append(request)
    if let failure { throw failure }
    guard let transform else { return request }
    return try await transform(request)
  }

  /// Configures a transformation and clears any previous failure.
  public func stubTransform(
    _ transform: @escaping @Sendable (HTTPRequest) async throws -> HTTPRequest
  ) {
    self.transform = transform
    failure = nil
  }

  /// Restores successful passthrough behavior.
  public func stubPassthrough() {
    transform = nil
    failure = nil
  }

  /// Makes subsequent processing throw the supplied error.
  public func stubFailure(_ error: any Error) { failure = error }

  /// Adds a header while preserving the identity and other fields of each request.
  public func stubAddHeader(_ name: HTTPHeaderName, value: HTTPHeaderValue) {
    stubTransform { request in
      var result = request
      result.addHeader(name: name, value: value)
      return result
    }
  }

  /// The number of requests processed since initialization or reset.
  public var callCount: MockVerificationCount { MockVerificationCount(requests.count) }

  /// Returns captured requests in call order.
  public func getCapturedRequests() -> [HTTPRequest] { requests }

  /// Returns the most recent captured request.
  public func getLastCapturedRequest() -> HTTPRequest? { requests.last }

  /// Clears configuration and history without changing already selected in-flight transformations.
  public func reset() {
    transform = nil
    failure = nil
    requests.removeAll()
  }
}
