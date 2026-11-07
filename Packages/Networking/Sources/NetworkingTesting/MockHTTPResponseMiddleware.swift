import NetworkingCore

/// Records responses and applies a configured transformation selected before suspension.
public actor MockHTTPResponseMiddleware: HTTPResponseMiddleware, MockVerifiable {
  private var transform: (@Sendable (HTTPResponse, HTTPRequest) async throws -> HTTPResponse)?
  private var failure: (any Error)?
  private var responses: [(request: HTTPRequest, response: HTTPResponse)] = []

  public init() {}

  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    responses.append((request, response))
    if let failure { throw failure }
    guard let transform else { return response }
    return try await transform(response, request)
  }

  public func stubTransform(
    _ transform: @escaping @Sendable (HTTPResponse, HTTPRequest) async throws -> HTTPResponse
  ) {
    self.transform = transform
    failure = nil
  }

  public func stubPassthrough() {
    transform = nil
    failure = nil
  }

  public func stubFailure(_ error: any Error) { failure = error }

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

  public var callCount: MockVerificationCount { MockVerificationCount(responses.count) }

  public func getCapturedResponses() -> [(request: HTTPRequest, response: HTTPResponse)] {
    responses
  }

  public func getLastCapturedResponse() -> (request: HTTPRequest, response: HTTPResponse)? {
    responses.last
  }

  public func reset() {
    transform = nil
    failure = nil
    responses.removeAll()
  }
}
