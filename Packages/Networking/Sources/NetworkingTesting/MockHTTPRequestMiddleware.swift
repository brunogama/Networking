import NetworkingCore

/// Records requests and applies a configured transformation selected before suspension.
public actor MockHTTPRequestMiddleware: HTTPRequestMiddleware, MockVerifiable {
  private var transform: (@Sendable (HTTPRequest) async throws -> HTTPRequest)?
  private var failure: (any Error)?
  private var requests: [HTTPRequest] = []

  public init() {}

  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    requests.append(request)
    if let failure { throw failure }
    guard let transform else { return request }
    return try await transform(request)
  }

  public func stubTransform(
    _ transform: @escaping @Sendable (HTTPRequest) async throws -> HTTPRequest
  ) {
    self.transform = transform
    failure = nil
  }

  public func stubPassthrough() {
    transform = nil
    failure = nil
  }

  public func stubFailure(_ error: any Error) { failure = error }

  public func stubAddHeader(_ name: HTTPHeaderName, value: HTTPHeaderValue) {
    stubTransform { request in
      var result = request
      result.addHeader(name: name, value: value)
      return result
    }
  }

  public var callCount: MockVerificationCount { MockVerificationCount(requests.count) }

  public func getCapturedRequests() -> [HTTPRequest] { requests }

  public func getLastCapturedRequest() -> HTTPRequest? { requests.last }

  public func reset() {
    transform = nil
    failure = nil
    requests.removeAll()
  }
}
