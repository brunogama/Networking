import Foundation

// MARK: - Authentication Strategy Extensions

extension AuthenticationStrategy {
  var tokenPrefix: AuthorizationTokenPrefix {
    switch self {
    case .bearerToken:
      return AuthorizationTokenPrefix(rawValue: "Bearer ")

    case .basicAuth:
      return AuthorizationTokenPrefix(rawValue: "Basic ")

    case .custom:
      return AuthorizationTokenPrefix(rawValue: "")
    }
  }
}

// MARK: - Token Provider Wrappers

/// Wrapper to adapt BearerTokenProvider to AuthenticationMiddleware.TokenProvider
struct BearerTokenProviderWrapper: AuthenticationMiddleware.TokenProvider {
  let provider: any BearerTokenProvider
  let refreshStrategy: AuthRefreshStrategy

  func getCurrentToken() async throws -> BearerTokenValue? {
    try await provider.getCurrentToken()
  }

  func refreshToken() async throws -> BearerTokenValue {
    switch refreshStrategy {
    case .none:
      throw HTTPError(
        category: .configuration(HTTPErrorDetail(rawValue: "Token refresh is disabled"))
      )

    case .automatic:
      return try await provider.refreshToken()

    case .manual(let handler):
      return try await handler()
    }
  }

  func shouldRefreshToken(for error: HTTPError) async -> AuthenticationDecision {
    // If refresh strategy is .none, don't refresh
    if case .none = refreshStrategy {
      return AuthenticationDecision(rawValue: false)
    }

    switch error.category {
    case .http(let status) where status.rawValue == 401:
      return AuthenticationDecision(rawValue: true)

    default:
      return AuthenticationDecision(rawValue: false)
    }
  }
}

/// Token provider for basic authentication
struct BasicAuthTokenProvider: AuthenticationMiddleware.TokenProvider {
  let username: BasicAuthUsername
  let password: BasicAuthPassword

  func getCurrentToken() async throws -> BearerTokenValue? {
    let credentials = "\(username.rawValue):\(password.rawValue)"
    guard let data = credentials.data(using: .utf8) else {
      throw HTTPError(
        category: .configuration(HTTPErrorDetail(rawValue: "Invalid basic auth credentials"))
      )
    }
    return BearerTokenValue(data.base64EncodedString())
  }

  func refreshToken() async throws -> BearerTokenValue {
    // Basic auth doesn't need refresh, return current token
    try await getCurrentToken() ?? BearerTokenValue(rawValue: "")
  }

  func shouldRefreshToken(for error: HTTPError) async -> AuthenticationDecision {
    // Basic auth typically doesn't require refresh
    AuthenticationDecision(rawValue: false)
  }
}

/// Token provider for custom authentication
struct CustomAuthTokenProvider: AuthenticationMiddleware.TokenProvider {
  let customProvider: any CustomAuthProvider

  func getCurrentToken() async throws -> BearerTokenValue? {
    // Custom providers handle token extraction differently
    nil
  }

  func refreshToken() async throws -> BearerTokenValue {
    throw HTTPError(
      category: .configuration(
        HTTPErrorDetail(rawValue: "Custom auth provider doesn't support token refresh")
      )
    )
  }

  func shouldRefreshToken(for error: HTTPError) async -> AuthenticationDecision {
    AuthenticationDecision(rawValue: false)
  }
}
