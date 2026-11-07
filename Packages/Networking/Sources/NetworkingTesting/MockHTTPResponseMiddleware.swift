import NetworkingCore

/// Records responses and applies a configured transformation selected before suspension.
public actor MockHTTPResponseMiddleware: HTTPResponseMiddleware, MockVerifiable {
  private var transform: (@Sendable (HTTPResponse, HTTPRequest) async throws -> HTTPResponse)?
  private var failure: (any Error)?
  private var responses: [(request: HTTPRequest, response: HTTPResponse)] = []

  /// Creates a middleware that returns responses unchanged.
  public init() {}

  /// Records the response, then applies the current behavior without later state mutation.
  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    responses.append((request, response))
    if let failure { throw failure }
    guard let transform else { return response }
    return try await transform(response, request)
  }

  /// Configures a transformation and clears any previous failure.
  public func stubTransform(
    _ transform: @escaping @Sendable (HTTPResponse, HTTPRequest) async throws -> HTTPResponse
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

  /// Replaces body bytes while preserving response metadata and the originating request.
  public func stubReplaceBody(_ body: HTTPBody) {
    stubTransform { response, _ in
      HTTPResponse(
        request: response.request,
        status: response.status,
        headers: response.headers,
        body: body,
        url: response.url
      )
    }
  }

  /// The number of responses processed since initialization or reset.
  public var callCount: MockVerificationCount { MockVerificationCount(responses.count) }

  /// Returns captured request and response pairs in call order.
  public func getCapturedResponses() -> [(request: HTTPRequest, response: HTTPResponse)] {
    responses
  }

  /// Returns the most recent captured pair.
  public func getLastCapturedResponse() -> (request: HTTPRequest, response: HTTPResponse)? {
    responses.last
  }

  /// Clears configuration and history without changing already selected in-flight transformations.
  public func reset() {
    transform = nil
    failure = nil
    responses.removeAll()
  }
}
