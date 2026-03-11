import Foundation
import NetworkingCore

/// Authentication middleware that handles token-based authentication with automatic refresh
/// and retry functionality for expired tokens.
public actor AuthenticationMiddleware: HTTPRequestMiddleware, HTTPErrorMiddleware {
  // MARK: - Token Provider Protocol

  /// Protocol for providing authentication tokens
  public protocol TokenProvider: Sendable {
    /// Returns the current access token
    func getCurrentToken() async throws -> BearerTokenValue?

    /// Refreshes the access token and returns the new token
    func refreshToken() async throws -> BearerTokenValue

    /// Determines if a token refresh should be attempted for the given error
    func shouldRefreshToken(for error: HTTPError) async -> AuthenticationDecision
  }

  // MARK: - Configuration

  /// Configuration for authentication middleware
  public struct Configuration: Sendable {
    /// The header name for the authorization token
    public let authorizationHeaderName: HTTPHeaderName

    /// The token prefix (e.g., "Bearer ")
    public let tokenPrefix: AuthorizationTokenPrefix

    /// Maximum number of refresh attempts
    public let maxRefreshAttempts: RetryAttemptCount

    /// Predicate to determine if authentication should be applied to a request
    public let shouldAuthenticate: @Sendable (HTTPRequest) -> AuthenticationDecision

    public init(
      authorizationHeaderName: HTTPHeaderName = "Authorization",
      tokenPrefix: AuthorizationTokenPrefix = "Bearer ",
      maxRefreshAttempts: RetryAttemptCount = 1,
      shouldAuthenticate: @escaping @Sendable (HTTPRequest) -> AuthenticationDecision = { _ in
        true
      }
    ) {
      self.authorizationHeaderName = authorizationHeaderName
      self.tokenPrefix = tokenPrefix
      self.maxRefreshAttempts = maxRefreshAttempts
      self.shouldAuthenticate = shouldAuthenticate
    }
  }

  // MARK: - Properties

  private let configuration: Configuration
  private let tokenProvider: any TokenProvider
  private let client: any HTTPClient

  // State for managing concurrent token refreshes
  private var refreshTask: Task<BearerTokenValue, any Error>?

  // MARK: - Initialization

  /// Creates a new authentication middleware
  /// - Parameters:
  ///   - configuration: The authentication configuration
  ///   - tokenProvider: The token provider implementation
  ///   - client: The HTTP client to use for requests
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
      timeout: request.timeout
    )
  }

  private func refreshTokenAndRetry(
    _ request: HTTPRequest,
    originalError: HTTPError
  ) async throws -> HTTPResponse {
    let newToken = try await getRefreshedToken()

    // Retry the request with the new token
    let authenticatedRequest = addAuthorizationHeader(to: request, token: newToken)

    do {
      return try await client.execute(authenticatedRequest)
    } catch let retryError as HTTPError {
      // If the retry also fails with an auth error, throw the original error
      if await tokenProvider.shouldRefreshToken(for: retryError).rawValue {
        throw originalError
      }
      throw retryError
    } catch {
      throw HTTPError(
        category: .network(.serverUnreachable),
        request: request,
        underlyingError: error
      )
    }
  }

  // REENTRANCY-SAFE: in-flight tracking pattern
  // Multiple concurrent calls share single refresh task
  private func getRefreshedToken() async throws -> BearerTokenValue {
    // Check if there's already a refresh task in progress - join existing
    if let existingTask = refreshTask {
      return try await existingTask.value
    }

    // Start new refresh - store task reference BEFORE await
    let task = Task<BearerTokenValue, any Error> {
      try await tokenProvider.refreshToken()
    }
    refreshTask = task

    // Clean up after completion (success or failure)
    defer { refreshTask = nil }

    let newToken = try await task.value
    return newToken
  }
}
