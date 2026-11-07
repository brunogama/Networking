import NetworkingCore

/// Records failures and runs an isolated, explicitly configured recovery behavior.
public actor MockHTTPErrorMiddleware: HTTPErrorMiddleware, MockVerifiable {
  private var handler: (@Sendable (HTTPError, HTTPRequest) async throws -> HTTPResponse)?
  private var errors: [(error: HTTPError, request: HTTPRequest)] = []

  /// Creates a middleware that rethrows each received failure.
  public init() {}

  /// Records the error and captures recovery behavior before suspension.
  public func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse
  {
    errors.append((error, request))
    guard let handler else { throw error }
    return try await handler(error, request)
  }

  /// Configures a custom recovery operation.
  public func stubHandler(
    _ handler: @escaping @Sendable (HTTPError, HTTPRequest) async throws -> HTTPResponse
  ) { self.handler = handler }

  /// Restores rethrow behavior.
  public func stubRethrow() { handler = nil }

  /// Returns a server-error response instead of throwing.
  public func stubSwallow() {
    handler = { _, request in
      HTTPResponse(request: request, status: .internalServerError, body: HTTPBody?.none)
    }
  }

  /// Returns the supplied recovery response for subsequent errors.
  public func stubRecoveryResponse(_ response: HTTPResponse) { handler = { _, _ in response } }

  /// The number of errors handled since initialization or reset.
  public var callCount: MockVerificationCount { MockVerificationCount(errors.count) }

  /// Returns handled errors and their requests in call order.
  public func getCapturedErrors() -> [(error: HTTPError, request: HTTPRequest)] { errors }

  /// Returns the most recently handled error and request.
  public func getLastCapturedError() -> (error: HTTPError, request: HTTPRequest)? { errors.last }

  /// Restores rethrow behavior and clears history without restoring it after in-flight operations.
  public func reset() {
    handler = nil
    errors.removeAll()
  }
}
