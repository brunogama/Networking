/// # Authentication Examples
///
/// This file demonstrates various authentication patterns and security mechanisms.
/// Shows integration with common authentication schemes and secure credential management.

import Foundation
import Networking

/// Collection of authentication examples for secure API access
public struct AuthenticationExamples {
  // MARK: - Public Interface

  /// Runs all authentication examples
  public static func runAll() async {
    print("\n🔐 Authentication Examples")
    print("-" * 30)

    await bearerTokenAuthentication()
    await apiKeyAuthentication()
    await basicAuthentication()
    await oauthFlowSimulation()
    await tokenRefreshPatterns()
    await customAuthenticationSchemes()
  }

  // MARK: - Bearer Token Authentication

  /// Demonstrates Bearer token authentication patterns
  ///
  /// Shows:
  /// - Bearer token header injection
  /// - Token-based API access
  /// - Authorization header management
  /// - Secure token handling
  public static func bearerTokenAuthentication() async {
    print("🔹 Bearer Token Authentication")

    do {
      // Simulate getting a bearer token (in real app, from secure storage)
      let bearerToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.demo-token"

      // Method 1: Manual header injection
      let client = HTTPClient()
      var request = HTTPRequest.get("https://httpbin.org/bearer")
      request.headers["Authorization"] = "Bearer \(bearerToken)"

      let response1 = try await client.send(request)
      print("   Manual Bearer Auth - Status: \(response1.status)")

      // Method 2: Using RequestBuilder DSL
      let request2 = RequestBuilder {
        HTTPMethod.get
        BaseURL("https://httpbin.org")
        Path("/bearer")
        Header("Authorization", "Bearer \(bearerToken)")
        Header("Accept", "application/json")
      }.build()

      let response2 = try await client.send(request2)
      print("   DSL Bearer Auth - Status: \(response2.status)")

      // Method 3: Using authentication middleware (more secure for multiple requests)
      let authClient = HTTPClient.Builder()
        .middleware(BearerTokenMiddleware(token: bearerToken))
        .build()

      let request3 = HTTPRequest.get("https://httpbin.org/bearer")
      let response3 = try await authClient.send(request3)
      print("   Middleware Bearer Auth - Status: \(response3.status)")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - API Key Authentication

  /// Demonstrates API key authentication in various forms
  ///
  /// Shows:
  /// - Header-based API keys
  /// - Query parameter API keys
  /// - Custom API key formats
  /// - Multi-key authentication
  public static func apiKeyAuthentication() async {
    print("🔹 API Key Authentication")

    do {
      let client = HTTPClient()
      let apiKey = "demo-api-key-12345"

      // Method 1: API key in custom header
      let headerRequest = RequestBuilder {
        HTTPMethod.get
        BaseURL("https://httpbin.org")
        Path("/get")
        Header("X-API-Key", apiKey)
        Header("Accept", "application/json")
      }.build()

      let response1 = try await client.send(headerRequest)
      print("   Header API Key - Status: \(response1.status)")

      // Method 2: API key as query parameter
      let queryRequest = RequestBuilder {
        HTTPMethod.get
        BaseURL("https://httpbin.org")
        Path("/get")
        QueryParam("api_key", apiKey)
        Header("Accept", "application/json")
      }.build()

      let response2 = try await client.send(queryRequest)
      print("   Query API Key - Status: \(response2.status)")

      // Method 3: Multiple API keys for different services
      struct MultiKeyConfig {
        let primaryKey: String
        let secondaryKey: String
        let clientId: String
      }

      let config = MultiKeyConfig(
        primaryKey: "primary-key-123",
        secondaryKey: "secondary-key-456",
        clientId: "client-789"
      )

      let multiKeyRequest = RequestBuilder {
        HTTPMethod.get
        BaseURL("https://httpbin.org")
        Path("/get")
        Header("X-Primary-API-Key", config.primaryKey)
        Header("X-Secondary-API-Key", config.secondaryKey)
        Header("X-Client-ID", config.clientId)
        Header("Accept", "application/json")
      }.build()

      let response3 = try await client.send(multiKeyRequest)
      print("   Multi-Key Authentication - Status: \(response3.status)")

      // Method 4: API key with signature (HMAC-like pattern)
      let timestamp = String(Int(Date().timeIntervalSince1970))
      let signature = createSignature(
        apiKey: apiKey,
        timestamp: timestamp,
        method: "GET",
        path: "/get"
      )

      let signedRequest = RequestBuilder {
        HTTPMethod.get
        BaseURL("https://httpbin.org")
        Path("/get")
        Header("X-API-Key", apiKey)
        Header("X-Timestamp", timestamp)
        Header("X-Signature", signature)
        Header("Accept", "application/json")
      }.build()

      let response4 = try await client.send(signedRequest)
      print("   Signed API Key - Status: \(response4.status)")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Basic Authentication

  /// Demonstrates HTTP Basic Authentication
  ///
  /// Shows:
  /// - Username/password encoding
  /// - Base64 credential encoding
  /// - Basic auth header creation
  /// - Secure credential handling
  public static func basicAuthentication() async {
    print("🔹 Basic Authentication")

    do {
      let client = HTTPClient()

      // Test credentials (httpbin.org/basic-auth/user/passwd accepts these)
      let username = "testuser"
      let password = "testpass"

      // Method 1: Manual Basic Auth header creation
      let credentials = "\(username):\(password)"
      let encodedCredentials = Data(credentials.utf8).base64EncodedString()

      let request1 = RequestBuilder {
        HTTPMethod.get
        BaseURL("https://httpbin.org")
        Path("/basic-auth/\(username)/\(password)")
        Header("Authorization", "Basic \(encodedCredentials)")
        Header("Accept", "application/json")
      }.build()

      let response1 = try await client.send(request1)
      print("   Manual Basic Auth - Status: \(response1.status)")

      // Method 2: Using helper function for cleaner code
      func createBasicAuthHeader(username: String, password: String) -> String {
        let credentials = "\(username):\(password)"
        let encoded = Data(credentials.utf8).base64EncodedString()
        return "Basic \(encoded)"
      }

      let request2 = RequestBuilder {
        HTTPMethod.get
        BaseURL("https://httpbin.org")
        Path("/basic-auth/\(username)/\(password)")
        Header("Authorization", createBasicAuthHeader(username: username, password: password))
        Header("Accept", "application/json")
      }.build()

      let response2 = try await client.send(request2)
      print("   Helper Basic Auth - Status: \(response2.status)")

      // Method 3: Using middleware for automatic basic auth
      let basicAuthClient = HTTPClient.Builder()
        .middleware(BasicAuthenticationMiddleware(username: username, password: password))
        .build()

      let request3 = HTTPRequest.get("https://httpbin.org/basic-auth/\(username)/\(password)")
      let response3 = try await basicAuthClient.send(request3)
      print("   Middleware Basic Auth - Status: \(response3.status)")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - OAuth Flow Simulation

  /// Demonstrates OAuth 2.0 flow patterns
  ///
  /// Shows:
  /// - Authorization code flow simulation
  /// - Access token exchange
  /// - Token refresh patterns
  /// - PKCE (Proof Key for Code Exchange)
  public static func oauthFlowSimulation() async {
    print("🔹 OAuth Flow Simulation")

    do {
      // Simulate OAuth 2.0 Authorization Code Flow
      struct OAuthConfig {
        let clientId: String
        let clientSecret: String
        let redirectUri: String
        let scope: String
        let authorizationEndpoint: String
        let tokenEndpoint: String
      }

      let config = OAuthConfig(
        clientId: "demo-client-id",
        clientSecret: "demo-client-secret",
        redirectUri: "https://myapp.com/callback",
        scope: "read write",
        authorizationEndpoint: "https://httpbin.org/get",  // Simulated
        tokenEndpoint: "https://httpbin.org/post"  // Simulated
      )

      // Step 1: Generate authorization URL (normally shown to user)
      let authorizationURL = buildAuthorizationURL(config: config)
      print("   Step 1 - Authorization URL: \(authorizationURL)")

      // Step 2: Exchange authorization code for access token
      let authorizationCode = "demo-auth-code-12345"  // Simulated from callback
      let tokenResponse = try await exchangeCodeForToken(
        config: config,
        authorizationCode: authorizationCode
      )

      print("   Step 2 - Token Exchange Status: \(tokenResponse.status)")

      // Step 3: Use access token for API requests
      let accessToken = "demo-access-token-67890"  // Simulated from token response
      let apiRequest = RequestBuilder {
        HTTPMethod.get
        BaseURL("https://httpbin.org")
        Path("/bearer")
        Header("Authorization", "Bearer \(accessToken)")
        Header("Accept", "application/json")
      }.build()

      let client = HTTPClient()
      let apiResponse = try await client.send(apiRequest)
      print("   Step 3 - API Request with Token: \(apiResponse.status)")

      // PKCE (Proof Key for Code Exchange) simulation
      let pkceConfig = generatePKCEParameters()
      print("   PKCE Code Verifier Generated: \(pkceConfig.codeVerifier.prefix(10))...")
      print("   PKCE Code Challenge Generated: \(pkceConfig.codeChallenge.prefix(10))...")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Token Refresh Patterns

  /// Demonstrates token refresh and automatic retry patterns
  ///
  /// Shows:
  /// - Automatic token refresh on expiry
  /// - Refresh token handling
  /// - Retry logic for authentication failures
  /// - Token storage patterns
  public static func tokenRefreshPatterns() async {
    print("🔹 Token Refresh Patterns")

    do {
      // Simulate token storage and refresh
      class TokenManager {
        private var accessToken: String
        private var refreshToken: String
        private let tokenEndpoint: String

        init(accessToken: String, refreshToken: String, tokenEndpoint: String) {
          self.accessToken = accessToken
          self.refreshToken = refreshToken
          self.tokenEndpoint = tokenEndpoint
        }

        func getCurrentToken() -> String {
          accessToken
        }

        func refreshAccessToken() async throws -> String {
          // Simulate refresh token request
          let client = HTTPClient()
          let refreshRequest = RequestBuilder {
            HTTPMethod.post
            BaseURL(tokenEndpoint)
            Header("Content-Type", "application/x-www-form-urlencoded")

            let formData = "grant_type=refresh_token&refresh_token=\(refreshToken)"
            Body(formData.data(using: .utf8)!)
          }.build()

          let response = try await client.send(refreshRequest)

          if response.status == .ok {
            // Simulate parsing new token from response
            let newToken = "new-access-token-\(Int.random(in: 1000...9999))"
            self.accessToken = newToken
            print("   🔄 Token refreshed successfully")
            return newToken
          } else {
            throw HTTPError.unauthorized
          }
        }
      }

      let tokenManager = TokenManager(
        accessToken: "expired-token-123",
        refreshToken: "refresh-token-456",
        tokenEndpoint: "https://httpbin.org/post"
      )

      // Create middleware that automatically handles token refresh
      struct AutoRefreshMiddleware: Middleware {
        let tokenManager: TokenManager

        func process(
          _ request: HTTPRequest,
          next: @escaping (HTTPRequest) async throws -> HTTPResponse
        ) async throws -> HTTPResponse {
          // Add current token to request
          var authenticatedRequest = request
          authenticatedRequest.headers["Authorization"] = "Bearer \(tokenManager.getCurrentToken())"

          // Execute request
          let response = try await next(authenticatedRequest)

          // Check if token needs refresh
          if response.status == .unauthorized {
            print("   🔄 Token expired, attempting refresh...")

            do {
              let newToken = try await tokenManager.refreshAccessToken()

              // Retry request with new token
              authenticatedRequest.headers["Authorization"] = "Bearer \(newToken)"
              return try await next(authenticatedRequest)
            } catch {
              print("   ❌ Token refresh failed")
              throw error
            }
          }

          return response
        }
      }

      // Test the auto-refresh middleware
      let client = HTTPClient.Builder()
        .middleware(AutoRefreshMiddleware(tokenManager: tokenManager))
        .build()

      let request = HTTPRequest.get("https://httpbin.org/bearer")
      let response = try await client.send(request)
      print("   Auto-refresh middleware result: \(response.status)")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Custom Authentication Schemes

  /// Demonstrates custom authentication patterns for specific APIs
  ///
  /// Shows:
  /// - Custom signature generation
  /// - Timestamp-based authentication
  /// - Hash-based authentication
  /// - Multi-factor authentication patterns
  public static func customAuthenticationSchemes() async {
    print("🔹 Custom Authentication Schemes")

    do {
      let client = HTTPClient()

      // Custom Scheme 1: HMAC-SHA256 signature authentication
      let apiKey = "custom-api-key"
      let secretKey = "custom-secret-key"
      let timestamp = String(Int(Date().timeIntervalSince1970))

      let message = "GET\n/get\n\(timestamp)"
      let signature = generateHMACSignature(message: message, key: secretKey)

      let hmacRequest = RequestBuilder {
        HTTPMethod.get
        BaseURL("https://httpbin.org")
        Path("/get")
        Header("X-API-Key", apiKey)
        Header("X-Timestamp", timestamp)
        Header("X-Signature", signature)
        Header("Accept", "application/json")
      }.build()

      let response1 = try await client.send(hmacRequest)
      print("   HMAC Authentication - Status: \(response1.status)")

      // Custom Scheme 2: JWT-like token with custom claims
      let customToken = generateCustomJWTLikeToken(
        userId: "user123",
        permissions: ["read", "write"],
        expiresAt: Date().addingTimeInterval(3600)
      )

      let jwtRequest = RequestBuilder {
        HTTPMethod.get
        BaseURL("https://httpbin.org")
        Path("/bearer")
        Header("Authorization", "Custom \(customToken)")
        Header("Accept", "application/json")
      }.build()

      let response2 = try await client.send(jwtRequest)
      print("   Custom JWT-like Token - Status: \(response2.status)")

      // Custom Scheme 3: Multi-factor authentication headers
      struct MFACredentials {
        let username: String
        let password: String
        let totpCode: String
        let deviceId: String
      }

      let mfaCredentials = MFACredentials(
        username: "testuser",
        password: "testpass",
        totpCode: "123456",
        deviceId: "device-uuid-789"
      )

      let mfaRequest = RequestBuilder {
        HTTPMethod.post
        BaseURL("https://httpbin.org")
        Path("/post")
        Header("X-Username", mfaCredentials.username)
        Header("X-Password-Hash", hashPassword(mfaCredentials.password))
        Header("X-TOTP-Code", mfaCredentials.totpCode)
        Header("X-Device-ID", mfaCredentials.deviceId)
        Header("X-Auth-Method", "MFA")
        Header("Content-Type", "application/json")

        let bodyData = ["action": "login", "timestamp": timestamp]
        let jsonData = try JSONSerialization.data(withJSONObject: bodyData)
        Body(jsonData)
      }.build()

      let response3 = try await client.send(mfaRequest)
      print("   Multi-Factor Authentication - Status: \(response3.status)")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }
}

// MARK: - Authentication Middleware

/// Bearer token middleware for automatic token injection
private struct BearerTokenMiddleware: Middleware {
  let token: String

  func process(
    _ request: HTTPRequest,
    next: @escaping (HTTPRequest) async throws -> HTTPResponse
  ) async throws -> HTTPResponse {
    var authenticatedRequest = request
    authenticatedRequest.headers["Authorization"] = "Bearer \(token)"
    return try await next(authenticatedRequest)
  }
}

/// Basic authentication middleware
private struct BasicAuthenticationMiddleware: Middleware {
  let username: String
  let password: String

  func process(
    _ request: HTTPRequest,
    next: @escaping (HTTPRequest) async throws -> HTTPResponse
  ) async throws -> HTTPResponse {
    let credentials = "\(username):\(password)"
    let encoded = Data(credentials.utf8).base64EncodedString()

    var authenticatedRequest = request
    authenticatedRequest.headers["Authorization"] = "Basic \(encoded)"
    return try await next(authenticatedRequest)
  }
}

// MARK: - Authentication Helpers

/// Helper function to create API key signatures
private func createSignature(
  apiKey: String,
  timestamp: String,
  method: String,
  path: String
) -> String {
  let message = "\(method)\(path)\(timestamp)"
  return generateHMACSignature(message: message, key: apiKey)
}

/// Generate HMAC-SHA256 signature
private func generateHMACSignature(message: String, key: String) -> String {
  // Simplified signature generation for demo purposes
  // In production, use proper HMAC-SHA256 implementation
  let combinedString = "\(message):\(key)"
  let hash = combinedString.data(using: .utf8)?.base64EncodedString() ?? ""
  return String(hash.prefix(32))  // Truncate for demo
}

/// Build OAuth authorization URL
private func buildAuthorizationURL(config: AuthenticationExamples.OAuthConfig) -> String {
  var components = URLComponents(string: config.authorizationEndpoint)!
  components.queryItems = [
    URLQueryItem(name: "response_type", value: "code"),
    URLQueryItem(name: "client_id", value: config.clientId),
    URLQueryItem(name: "redirect_uri", value: config.redirectUri),
    URLQueryItem(name: "scope", value: config.scope),
    URLQueryItem(name: "state", value: UUID().uuidString),
  ]
  return components.url?.absoluteString ?? config.authorizationEndpoint
}

/// Exchange authorization code for access token
private func exchangeCodeForToken(
  config: AuthenticationExamples.OAuthConfig,
  authorizationCode: String
) async throws -> HTTPResponse {
  let client = HTTPClient()

  let tokenRequest = RequestBuilder {
    HTTPMethod.post
    BaseURL(config.tokenEndpoint)
    Header("Content-Type", "application/x-www-form-urlencoded")
    Header("Accept", "application/json")

    let formData = [
      "grant_type=authorization_code",
      "code=\(authorizationCode)",
      "redirect_uri=\(config.redirectUri)",
      "client_id=\(config.clientId)",
      "client_secret=\(config.clientSecret)",
    ].joined(separator: "&")

    Body(formData.data(using: .utf8)!)
  }.build()

  return try await client.send(tokenRequest)
}

/// Generate PKCE parameters
private func generatePKCEParameters() -> (codeVerifier: String, codeChallenge: String) {
  // Simplified PKCE generation for demo purposes
  let codeVerifier = UUID().uuidString + UUID().uuidString
  let codeChallenge = Data(codeVerifier.utf8).base64EncodedString()
    .replacingOccurrences(of: "+", with: "-")
    .replacingOccurrences(of: "/", with: "_")
    .replacingOccurrences(of: "=", with: "")

  return (codeVerifier: codeVerifier, codeChallenge: codeChallenge)
}

/// Generate custom JWT-like token for demonstration
private func generateCustomJWTLikeToken(
  userId: String,
  permissions: [String],
  expiresAt: Date
) -> String {
  // Simplified token generation for demo purposes
  let header = ["typ": "JWT", "alg": "HS256"]
  let payload =
    [
      "sub": userId,
      "permissions": permissions.joined(separator: ","),
      "exp": String(Int(expiresAt.timeIntervalSince1970)),
    ] as [String: Any]

  let headerData = try! JSONSerialization.data(withJSONObject: header)
  let payloadData = try! JSONSerialization.data(withJSONObject: payload)

  let encodedHeader = headerData.base64EncodedString()
  let encodedPayload = payloadData.base64EncodedString()
  let signature = "demo-signature"

  return "\(encodedHeader).\(encodedPayload).\(signature)"
}

/// Hash password for secure transmission
private func hashPassword(_ password: String) -> String {
  // Simplified hashing for demo purposes
  // In production, use proper password hashing like bcrypt or Argon2
  Data(password.utf8).base64EncodedString()
}

// MARK: - OAuth Configuration Extension

private extension AuthenticationExamples {
  struct OAuthConfig {
    let clientId: String
    let clientSecret: String
    let redirectUri: String
    let scope: String
    let authorizationEndpoint: String
    let tokenEndpoint: String
  }
}

// MARK: - Helper Extensions

private extension String {
  static func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
  }
}
