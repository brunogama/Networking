# Authentication

Comprehensive authentication support with automatic token management.

## Overview

ModernNetworking provides robust authentication capabilities including Bearer tokens, Basic authentication, API keys, and custom authentication schemes. The framework handles token refresh, authentication errors, and secure credential storage automatically.

## Authentication Configuration

### Bearer Token Authentication

Configure Bearer token authentication with automatic refresh:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Authentication {
        BearerToken(tokenProvider)
        AuthRefreshStrategy(.automatic)
        AuthenticateWhen { request in
            !request.url.path.hasPrefix("/public/")
        }
    }
}
```

### Basic Authentication

Set up HTTP Basic authentication:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Authentication {
        ClientBasicAuth(username: "api_user", password: "secret_key")
    }
}
```

### API Key Authentication

Configure API key authentication:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    DefaultHeader("X-API-Key", apiKey)
}

// Or per-request
let response = try await client.execute {
    GET("/api/data")
    APIKey(key: apiKey, headerName: "X-API-Key")
}
```

## Token Providers

### Static Token Provider

For tokens that don't need refresh:

```swift
let staticProvider = StaticTokenProvider(token: "your-static-token")

let client = NetworkClient {
    BaseURL("https://api.example.com")
    Authentication {
        BearerToken(staticProvider)
    }
}
```

### Dynamic Token Provider

For tokens that need to be fetched or refreshed:

```swift
let dynamicProvider = ClosureBearerTokenProvider(
    getCurrentToken: {
        // Fetch current token from secure storage
        return try await KeychainService.retrieve("access_token")
    },
    refreshToken: {
        // Refresh the token using refresh token
        let refreshToken = try await KeychainService.retrieve("refresh_token")
        let tokens = try await authService.refreshTokens(refreshToken: refreshToken)
        
        // Store new tokens securely
        try await KeychainService.store(tokens.accessToken, forKey: "access_token")
        try await KeychainService.store(tokens.refreshToken, forKey: "refresh_token")
        
        return tokens.accessToken
    }
)
```

### Custom Token Provider

Implement ``BearerTokenProvider`` for custom logic:

```swift
struct CustomTokenProvider: BearerTokenProvider {
    private let authService: AuthenticationService
    private let keychain: KeychainService
    
    func getCurrentToken() async throws -> String? {
        // Check if token exists and is valid
        guard let token = try await keychain.retrieve("access_token") else {
            return nil
        }
        
        // Validate token expiration
        if await isTokenExpired(token) {
            return nil // Will trigger refresh
        }
        
        return token
    }
    
    func refreshToken() async throws -> String {
        // Get refresh token
        guard let refreshToken = try await keychain.retrieve("refresh_token") else {
            throw AuthenticationError.noRefreshToken
        }
        
        // Call authentication service
        let newTokens = try await authService.refreshAccessToken(refreshToken)
        
        // Store new tokens
        try await keychain.store(newTokens.accessToken, forKey: "access_token")
        
        // Update refresh token if provided
        if let newRefreshToken = newTokens.refreshToken {
            try await keychain.store(newRefreshToken, forKey: "refresh_token")
        }
        
        return newTokens.accessToken
    }
    
    private func isTokenExpired(_ token: String) async -> Bool {
        // Decode JWT token and check expiration
        // Implementation depends on your token format
        return await JWTDecoder.isExpired(token)
    }
}
```

## Authentication Strategies

### Automatic Token Refresh

Configure automatic token refresh on authentication failures:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Authentication {
        BearerToken(tokenProvider)
        AuthRefreshStrategy(.automatic)
        
        // Optional: Configure refresh behavior
        AuthorizationHeader("Authorization")
        AuthenticateWhen { request in
            // Define which requests need authentication
            !request.url.path.contains("/public/")
        }
    }
}
```

### Manual Token Refresh

Handle token refresh manually:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Authentication {
        BearerToken(tokenProvider)
        AuthRefreshStrategy(.manual { 
            // Custom refresh logic
            let newToken = try await performCustomTokenRefresh()
            return newToken
        })
    }
}
```

### No Token Refresh

Disable automatic refresh:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Authentication {
        BearerToken(tokenProvider)
        AuthRefreshStrategy(.none) // No automatic refresh
    }
}
```

## Custom Authentication

### Custom Authentication Provider

Implement ``CustomAuthProvider`` for complex authentication:

```swift
struct OAuth2AuthProvider: CustomAuthProvider {
    private let clientId: String
    private let clientSecret: String
    private let tokenEndpoint: URL
    
    func authenticateRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
        // Get access token
        let accessToken = try await getAccessToken()
        
        // Add to request
        var headers = request.headers
        headers["Authorization"] = "Bearer \(accessToken)"
        
        return HTTPRequest(
            method: request.method,
            url: request.url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
        )
    }
    
    func handleAuthenticationError(
        _ error: HTTPError,
        for request: HTTPRequest
    ) async throws -> HTTPResponse? {
        // Check if this is an authentication error we can handle
        guard case .http(let status) = error.category,
              status.rawValue == 401 else {
            return nil
        }
        
        // Try to refresh token and retry
        do {
            try await refreshAccessToken()
            
            // Retry the original request with new token
            let authenticatedRequest = try await authenticateRequest(request)
            
            // This would need access to the HTTP client to execute
            // In practice, this is handled by the middleware system
            return nil // Middleware will handle the retry
            
        } catch {
            // Refresh failed, authentication required
            throw AuthenticationError.refreshFailed
        }
    }
    
    private func getAccessToken() async throws -> String {
        // Implementation for getting current access token
        if let cachedToken = await TokenCache.shared.getToken(),
           !await isTokenExpired(cachedToken) {
            return cachedToken
        }
        
        return try await refreshAccessToken()
    }
    
    private func refreshAccessToken() async throws -> String {
        // OAuth2 token refresh implementation
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = "grant_type=client_credentials&client_id=\(clientId)&client_secret=\(clientSecret)"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthenticationError.tokenRefreshFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        // Cache the new token
        await TokenCache.shared.storeToken(tokenResponse.accessToken)
        
        return tokenResponse.accessToken
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}
```

## Per-Request Authentication

### Request-Level Authentication

Override client authentication for specific requests:

```swift
// Client has default authentication
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Authentication {
        BearerToken(defaultTokenProvider)
    }
}

// Use different authentication for specific request
let response = try await client.execute {
    POST("/api/admin/action")
    BearerAuth(adminToken) // Override default authentication
}
```

### Conditional Authentication

Apply authentication conditionally:

```swift
let client = NetworkClient {
    BaseURL("https://api.example.com")
    Authentication {
        BearerToken(tokenProvider)
        AuthenticateWhen { request in
            // Only authenticate non-public endpoints
            return !request.url.path.hasPrefix("/public/") &&
                   !request.url.path.hasPrefix("/health")
        }
    }
}
```

## OAuth2 Integration

### Authorization Code Flow

Implement OAuth2 authorization code flow:

```swift
class OAuth2Manager {
    private let clientId: String
    private let redirectURI: String
    private let authorizationEndpoint: URL
    private let tokenEndpoint: URL
    
    func startAuthorizationFlow() -> URL {
        let state = UUID().uuidString
        UserDefaults.standard.set(state, forKey: "oauth_state")
        
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: "read write")
        ]
        
        return components.url!
    }
    
    func handleAuthorizationCallback(url: URL) async throws -> TokenResponse {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw OAuth2Error.invalidCallback
        }
        
        // Verify state parameter
        let state = queryItems.first { $0.name == "state" }?.value
        let expectedState = UserDefaults.standard.string(forKey: "oauth_state")
        guard state == expectedState else {
            throw OAuth2Error.stateMismatch
        }
        
        // Get authorization code
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw OAuth2Error.noAuthorizationCode
        }
        
        // Exchange code for token
        return try await exchangeCodeForToken(code)
    }
    
    private func exchangeCodeForToken(_ code: String) async throws -> TokenResponse {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "code": code,
            "redirect_uri": redirectURI
        ]
        
        let bodyString = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuth2Error.tokenExchangeFailed
        }
        
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
}

enum OAuth2Error: Error {
    case invalidCallback
    case stateMismatch
    case noAuthorizationCode
    case tokenExchangeFailed
}
```

### PKCE Support

Implement Proof Key for Code Exchange (PKCE):

```swift
class PKCEManager {
    struct PKCEChallenge {
        let codeVerifier: String
        let codeChallenge: String
        let codeChallengeMethod: String = "S256"
    }
    
    func generatePKCEChallenge() -> PKCEChallenge {
        // Generate code verifier (43-128 characters)
        let codeVerifier = generateRandomString(length: 128)
        
        // Create SHA256 hash
        let data = codeVerifier.data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        
        // Base64 URL encode
        let codeChallenge = Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return PKCEChallenge(
            codeVerifier: codeVerifier,
            codeChallenge: codeChallenge
        )
    }
    
    private func generateRandomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}
```

## Secure Token Storage

### Keychain Integration

Use the built-in keychain service for secure token storage:

```swift
class SecureTokenStorage {
    private let keychain = KeychainService(
        service: "com.myapp.tokens",
        accessGroup: nil,
        accessibility: .whenUnlockedThisDeviceOnly
    )
    
    func storeTokens(_ tokens: TokenResponse) async throws {
        // Store access token
        try await keychain.store(
            tokens.accessToken,
            forKey: "access_token"
        )
        
        // Store refresh token if available
        if let refreshToken = tokens.refreshToken {
            try await keychain.store(
                refreshToken,
                forKey: "refresh_token"
            )
        }
        
        // Store expiration time
        let expirationDate = Date().addingTimeInterval(TimeInterval(tokens.expiresIn))
        let expirationData = try JSONEncoder().encode(expirationDate)
        try await keychain.store(
            expirationData,
            forKey: "token_expiration"
        )
    }
    
    func getAccessToken() async throws -> String? {
        // Check if token is expired
        if let expirationData = try await keychain.retrieve("token_expiration"),
           let expirationDate = try? JSONDecoder().decode(Date.self, from: expirationData),
           Date() > expirationDate {
            return nil // Token expired
        }
        
        return try await keychain.retrieve("access_token")
    }
    
    func getRefreshToken() async throws -> String? {
        return try await keychain.retrieve("refresh_token")
    }
    
    func clearTokens() async throws {
        try await keychain.delete("access_token")
        try await keychain.delete("refresh_token")
        try await keychain.delete("token_expiration")
    }
}
```

### Biometric Authentication

Add biometric authentication for sensitive operations:

```swift
extension KeychainService {
    func storeWithBiometrics<T: Codable>(
        _ item: T,
        forKey key: String
    ) async throws {
        let data = try JSONEncoder().encode(item)
        
        try await keychain.store(
            data,
            forKey: key,
            accessibility: .whenUnlockedThisDeviceOnly,
            authenticationPolicy: .biometryAny
        )
    }
    
    func retrieveWithBiometrics<T: Codable>(
        _ type: T.Type,
        forKey key: String,
        prompt: String = "Authenticate to access token"
    ) async throws -> T? {
        guard let data = try await keychain.retrieve(
            key,
            authenticationPrompt: prompt
        ) else {
            return nil
        }
        
        return try JSONDecoder().decode(type, from: data)
    }
}
```

## Error Handling

### Authentication Errors

Handle authentication-specific errors:

```swift
enum AuthenticationError: Error, LocalizedError {
    case noToken
    case tokenExpired
    case refreshFailed
    case invalidCredentials
    case biometricAuthenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .noToken:
            return "No authentication token available"
        case .tokenExpired:
            return "Authentication token has expired"
        case .refreshFailed:
            return "Failed to refresh authentication token"
        case .invalidCredentials:
            return "Invalid authentication credentials"
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed"
        }
    }
}

func handleAuthenticationError(_ error: HTTPError) async {
    switch error.category {
    case .http(let status) where status.rawValue == 401:
        // Token expired or invalid
        do {
            // Try to refresh token
            try await tokenProvider.refreshToken()
            // Retry the original request...
            
        } catch {
            // Refresh failed, redirect to login
            await MainActor.run {
                presentLoginScreen()
            }
        }
        
    case .http(let status) where status.rawValue == 403:
        // Insufficient permissions
        await MainActor.run {
            presentPermissionDeniedAlert()
        }
        
    default:
        // Other errors
        break
    }
}
```

## Testing Authentication

### Mock Token Provider

Create mock providers for testing:

```swift
class MockTokenProvider: BearerTokenProvider {
    var currentToken: String?
    var refreshTokenResult: Result<String, Error> = .success("new-token")
    
    func getCurrentToken() async throws -> String? {
        return currentToken
    }
    
    func refreshToken() async throws -> String {
        switch refreshTokenResult {
        case .success(let token):
            currentToken = token
            return token
        case .failure(let error):
            throw error
        }
    }
}

// Usage in tests
@Test("Authentication middleware refreshes expired tokens")
func testTokenRefresh() async throws {
    let mockProvider = MockTokenProvider()
    mockProvider.currentToken = "expired-token"
    mockProvider.refreshTokenResult = .success("refreshed-token")
    
    let client = NetworkClient {
        Authentication {
            BearerToken(mockProvider)
            AuthRefreshStrategy(.automatic)
        }
    }
    
    // Test that requests with 401 responses trigger token refresh
    // Implementation depends on your testing setup
}
```

## Related Topics

- <doc:Client-Configuration>: Complete authentication configuration
- <doc:Security-Features>: Secure credential storage and transmission
- <doc:Error-Handling>: Handling authentication errors
- <doc:Middleware-Guide>: Custom authentication middleware