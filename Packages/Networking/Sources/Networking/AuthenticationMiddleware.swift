import Foundation

/// Authentication middleware that handles token-based authentication with automatic refresh
/// and retry functionality for expired tokens.
public actor AuthenticationMiddleware: HTTPRequestMiddleware, HTTPErrorMiddleware {
  // MARK: - Token Provider Protocol

  /// Protocol for providing authentication tokens
  public protocol TokenProvider: Sendable {
    /// Returns the current access token
    func getCurrentToken() async throws -> String?

    /// Refreshes the access token and returns the new token
    func refreshToken() async throws -> String

    /// Determines if a token refresh should be attempted for the given error
    func shouldRefreshToken(for error: HTTPError) async -> Bool
  }

  // MARK: - Configuration

  /// Configuration for authentication middleware
  public struct Configuration: Sendable {
    /// The header name for the authorization token
    public let authorizationHeaderName: String

    /// The token prefix (e.g., "Bearer ")
    public let tokenPrefix: String

    /// Maximum number of refresh attempts
    public let maxRefreshAttempts: Int

    /// Predicate to determine if authentication should be applied to a request
    public let shouldAuthenticate: @Sendable (HTTPRequest) -> Bool

    public init(
      authorizationHeaderName: String = "Authorization",
      tokenPrefix: String = "Bearer ",
      maxRefreshAttempts: Int = 1,
      shouldAuthenticate: @escaping @Sendable (HTTPRequest) -> Bool = { _ in true }
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
  private var refreshTask: Task<String, any Error>?

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
    guard configuration.shouldAuthenticate(request) else {
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
    guard await tokenProvider.shouldRefreshToken(for: error),
      configuration.shouldAuthenticate(request)
    else {
      throw error
    }

    // Attempt to refresh token and retry request
    return try await refreshTokenAndRetry(request, originalError: error)
  }

  // MARK: - Private Methods

  private func addAuthorizationHeader(to request: HTTPRequest, token: String) -> HTTPRequest {
    var headers = request.headers
    headers[configuration.authorizationHeaderName] = "\(configuration.tokenPrefix)\(token)"

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
      if await tokenProvider.shouldRefreshToken(for: retryError) {
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
  private func getRefreshedToken() async throws -> String {
    // Check if there's already a refresh task in progress - join existing
    if let existingTask = refreshTask {
      return try await existingTask.value
    }

    // Start new refresh - store task reference BEFORE await
    let task = Task<String, any Error> {
      try await tokenProvider.refreshToken()
    }
    refreshTask = task

    // Clean up after completion (success or failure)
    defer { refreshTask = nil }

    let newToken = try await task.value
    return newToken
  }
}

// MARK: - Default Token Provider Implementations

/// A simple token provider that stores tokens in memory
public actor MemoryTokenProvider: AuthenticationMiddleware.TokenProvider {
  private var accessToken: String?
  private let refreshHandler: @Sendable () async throws -> String

  /// Creates a memory-based token provider
  /// - Parameters:
  ///   - initialToken: The initial access token
  ///   - refreshHandler: A closure that handles token refresh
  public init(
    initialToken: String? = nil,
    refreshHandler: @escaping @Sendable () async throws -> String
  ) {
    self.accessToken = initialToken
    self.refreshHandler = refreshHandler
  }

  public func getCurrentToken() async throws -> String? {
    accessToken
  }

  public func refreshToken() async throws -> String {
    let newToken = try await refreshHandler()
    accessToken = newToken
    return newToken
  }

  public func shouldRefreshToken(for error: HTTPError) async -> Bool {
    switch error.category {
    case .http(let status) where status.rawValue == 401:
      return true

    default:
      return false
    }
  }

  /// Updates the stored access token
  /// - Parameter token: The new access token
  public func setToken(_ token: String?) async {
    accessToken = token
  }
}

/// A token provider that uses closures for all operations
public struct ClosureTokenProvider: AuthenticationMiddleware.TokenProvider {
  private let getCurrentHandler: @Sendable () async throws -> String?
  private let refreshHandler: @Sendable () async throws -> String
  private let shouldRefreshHandler: @Sendable (HTTPError) async -> Bool

  /// Creates a closure-based token provider
  /// - Parameters:
  ///   - getCurrentToken: Closure to get the current token
  ///   - refreshToken: Closure to refresh the token
  ///   - shouldRefreshToken: Closure to determine if refresh should be attempted
  public init(
    getCurrentToken: @escaping @Sendable () async throws -> String?,
    refreshToken: @escaping @Sendable () async throws -> String,
    shouldRefreshToken: @escaping @Sendable (HTTPError) async -> Bool = { error in
      if case .http(let status) = error.category, status.rawValue == 401 {
        return true
      }
      return false
    }
  ) {
    self.getCurrentHandler = getCurrentToken
    self.refreshHandler = refreshToken
    self.shouldRefreshHandler = shouldRefreshToken
  }

  public func getCurrentToken() async throws -> String? {
    try await getCurrentHandler()
  }

  public func refreshToken() async throws -> String {
    try await refreshHandler()
  }

  public func shouldRefreshToken(for error: HTTPError) async -> Bool {
    await shouldRefreshHandler(error)
  }
}

// MARK: - Convenience Factory

extension AuthenticationMiddleware {
  /// Creates an authentication middleware with a memory-based token provider
  /// - Parameters:
  ///   - client: The HTTP client to use
  ///   - initialToken: The initial access token
  ///   - refreshHandler: Closure to handle token refresh
  /// - Returns: A configured authentication middleware
  public static func withMemoryProvider(
    client: any HTTPClient,
    initialToken: String? = nil,
    refreshHandler: @escaping @Sendable () async throws -> String
  ) -> AuthenticationMiddleware {
    let tokenProvider = MemoryTokenProvider(
      initialToken: initialToken,
      refreshHandler: refreshHandler
    )

    return AuthenticationMiddleware(
      configuration: Configuration(),
      tokenProvider: tokenProvider,
      client: client
    )
  }

  /// Creates an authentication middleware with closure-based token provider
  /// - Parameters:
  ///   - client: The HTTP client to use
  ///   - getCurrentToken: Closure to get the current token
  ///   - refreshToken: Closure to refresh the token
  /// - Returns: A configured authentication middleware
  public static func withClosureProvider(
    client: any HTTPClient,
    getCurrentToken: @escaping @Sendable () async throws -> String?,
    refreshToken: @escaping @Sendable () async throws -> String
  ) -> AuthenticationMiddleware {
    let tokenProvider = ClosureTokenProvider(
      getCurrentToken: getCurrentToken,
      refreshToken: refreshToken
    )

    return AuthenticationMiddleware(
      configuration: Configuration(),
      tokenProvider: tokenProvider,
      client: client
    )
  }
}
