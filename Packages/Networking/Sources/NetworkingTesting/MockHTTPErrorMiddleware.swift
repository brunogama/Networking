import NetworkingCore

/// Records failures and runs an isolated, explicitly configured recovery behavior.
public actor MockHTTPErrorMiddleware: HTTPErrorMiddleware, MockVerifiable {
  private var handler: (@Sendable (HTTPError, HTTPRequest) async throws -> HTTPResponse)?
  private var errors: [(error: HTTPError, request: HTTPRequest)] = []

  public init() {}

  public func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse
  {
    errors.append((error, request))
    guard let handler else { throw error }
    return try await handler(error, request)
  }

  public func stubHandler(
    _ handler: @escaping @Sendable (HTTPError, HTTPRequest) async throws -> HTTPResponse
  ) { self.handler = handler }

  public func stubRethrow() { handler = nil }

  public func stubSwallow() {
    handler = { _, request in
      HTTPResponse(request: request, status: .internalServerError, body: HTTPBody?.none)
    }
  }

  public func stubRecoveryResponse(_ response: HTTPResponse) { handler = { _, _ in response } }

  public var callCount: MockVerificationCount { MockVerificationCount(errors.count) }

  public func getCapturedErrors() -> [(error: HTTPError, request: HTTPRequest)] { errors }

  public func getLastCapturedError() -> (error: HTTPError, request: HTTPRequest)? { errors.last }

  public func reset() {
    handler = nil
    errors.removeAll()
  }
}
