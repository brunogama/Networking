import NetworkingCore

/// Authentication middleware that handles token-based authentication with automatic refresh.
/// and retry functionality for expired tokens.
public actor AuthenticationMiddleware: HTTPRequestMiddleware, HTTPErrorMiddleware {

  // MARK: - Properties

  private let configuration: Configuration
  private let tokenProvider: any TokenProvider
  private let client: any HTTPClient

  private var refreshState: AuthenticationRefreshState = .idle

  // MARK: - Initialization

  public init(
    configuration: Configuration,
    tokenProvider: any TokenProvider,
    client: any HTTPClient
  ) {
    self.configuration = configuration
    self.tokenProvider = tokenProvider
    self.client = client
  }

  // MARK: - HTTPRequestMiddleware

  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    guard configuration.shouldAuthenticate(request).rawValue else {
      return request
    }

    // Skip authentication if the request already has an authorization header
    if request.headers[configuration.authorizationHeaderName] != nil {
      return request
    }

    guard let token = try await tokenProvider.getCurrentToken() else {
      // No token available, proceed without authentication
      return request
    }

    return addAuthorizationHeader(to: request, token: token)
  }

  // MARK: - HTTPErrorMiddleware

  public func handleError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    // Only handle authentication-related errors
    guard await tokenProvider.shouldRefreshToken(for: error).rawValue,
      configuration.shouldAuthenticate(request).rawValue
    else {
      throw error
    }

    // Attempt to refresh token and retry request
    return try await refreshTokenAndRetry(request, originalError: error)
  }

  // MARK: - Private Methods

  private func addAuthorizationHeader(
    to request: HTTPRequest,
    token: BearerTokenValue
  ) -> HTTPRequest {
    var headers = request.headers
    headers[configuration.authorizationHeaderName] = HTTPHeaderValue(
      "\(configuration.tokenPrefix.rawValue)\(token.rawValue)"
    )

    return HTTPRequest(
      method: request.method,
      url: request.url,
      headers: headers,
      body: request.body,
      timeout: request.timeoutOverride,
      id: request.id
    )
  }

  private func refreshTokenAndRetry(
    _ request: HTTPRequest,
    originalError: HTTPError
  ) async throws -> HTTPResponse {
    var failure = originalError
    for _ in 0..<max(0, configuration.maxRefreshAttempts.rawValue) {
      let token = try await getRefreshedToken()
      try Task.checkCancellation()
      do {
        return try await client.execute(addAuthorizationHeader(to: request, token: token))
      } catch let error as HTTPError {
        guard await tokenProvider.shouldRefreshToken(for: error).rawValue else { throw error }
        failure = error
      }
    }
    throw failure
  }

  private func getRefreshedToken() async throws -> BearerTokenValue {
    try Task.checkCancellation()
    let flight = refreshFlight()
    defer { complete(flight) }
    let newToken = try await flight.task.value
    try Task.checkCancellation()
    return newToken
  }

  private func refreshFlight() -> AuthenticationRefreshFlight {
    if case .refreshing(let flight) = refreshState { return flight }

    let provider = tokenProvider
    // The actor owns this shared flight. It is cancelled only when the actor is released, rather
    // than by an individual waiter, so one cancelled request cannot abort another refresh.
    let flight = AuthenticationRefreshFlight(
      task: Task { try await provider.refreshToken() }
    )
    refreshState = .refreshing(flight)
    return flight
  }

  private func complete(_ flight: borrowing AuthenticationRefreshFlight) {
    guard case .refreshing(let current) = refreshState, current.isSame(as: flight) else { return }
    refreshState = .idle
  }

  deinit {
    guard case .refreshing(let flight) = refreshState else { return }
    flight.cancel()
  }
}
