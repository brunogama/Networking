/// # Advanced Request Building Examples
///
/// This file demonstrates advanced request construction patterns using the RequestBuilder DSL,
/// focusing on middleware architecture, complex composition patterns, and production-ready
/// request building techniques.
///
/// ## Key Features Demonstrated
///
/// - **Complex DSL Composition**: Advanced patterns with nested components and conditional logic
/// - **Authentication Flows**: Token refresh, credential rotation, and multi-auth scenarios
/// - **Middleware Integration**: Custom request/response transformation and processing
/// - **Request Templates**: Reusable builders for common API patterns
/// - **Dynamic Request Generation**: Data-driven request construction
/// - **Advanced Body Handling**: JSON, Form, and custom body types with validation
/// - **Configuration Components**: Timeout, caching, headers, and behavior control
///
/// ## Architecture Overview
///
/// The advanced request building system leverages Swift's result builder pattern to create
/// composable, type-safe HTTP request construction. Each component implements the
/// `RequestComponent` protocol and can be combined declaratively.
///
/// ```swift
/// let request = try RequestBuilder.build {
///     GET("/api/v2/users")
///     RequestBaseURL("https://api.example.com")
///     BearerAuth(token)
///     RequestTimeout(.seconds(30))
///     AcceptHeader(.json)
///     if includeMetadata {
///         QueryParams(["include": "metadata", "expand": "profile"])
///     }
/// }
/// ```
///
/// ## Framework Components Reference
///
/// ### HTTP Methods
/// - `GET(path)`, `POST(path)`, `PUT(path)`, `DELETE(path)`, `PATCH(path)`
/// - `HEAD(path)`, `OPTIONS(path)`, `TRACE(path)`, `CONNECT(path)`
///
/// ### Authentication
/// - `BearerAuth(token)` - OAuth 2.0 Bearer token authentication
/// - `RequestBasicAuth(username, password)` - HTTP Basic authentication
/// - `APIKey(key, headerName)` - API key authentication with custom header
///
/// ### Request Configuration
/// - `RequestBaseURL(url)` - Base URL for the request
/// - `Header(name, value)` - Custom HTTP header
/// - `ContentType(mediaType)` - Content-Type header with validation
/// - `AcceptHeader(mediaType)` - Accept header for content negotiation
/// - `UserAgent(agent)` - User-Agent header
/// - `RequestTimeout(interval)` - Request timeout configuration
///
/// ### Query Parameters
/// - `RequestQueryParam(name, value)` - Single query parameter
/// - `QueryParams(dictionary)` - Multiple query parameters from dictionary
///
/// ### Request Bodies
/// - `JSONBody(encodable)` - JSON serialization of Codable types
/// - `DataBody(data)` - Raw data body
/// - `FormBody(parameters)` - URL-encoded form data
///
/// ### Advanced Components
/// - `ConditionalComponent(condition, component)` - Conditional inclusion
/// - `CompositeComponent(components)` - Group multiple components
/// - `EmptyComponent()` - No-op component for conditional flows

import Foundation
import Networking

// MARK: - Platform Compatibility

#if canImport(UIKit)
import UIKit
#else
// Provide macOS/other platform fallback for UIDevice
private struct DeviceInfo {
  static var current: Self { Self() }
  var identifierForVendor: UUID? { UUID() }
  var systemVersion: String { "Unknown" }
  var model: String { "Mac" }
}
private let UIDevice = DeviceInfo.self
#endif

/// Advanced request building patterns and middleware demonstrations
///
/// This structure provides comprehensive examples of sophisticated HTTP request construction
/// patterns using the RequestBuilder DSL. Each method demonstrates different aspects of
/// advanced request building suitable for production applications.
public struct AdvancedRequestBuilding {
  // MARK: - Public Interface

  /// Runs all advanced request building examples
  ///
  /// Executes a comprehensive suite of advanced request building demonstrations,
  /// showing complex DSL patterns, authentication flows, middleware integration,
  /// and dynamic request generation techniques.
  public static func runAll() async {
    print("\n🏗️ Advanced Request Building Examples")
    print("-" * 50)

    await complexDSLPatterns()
    await authenticationFlows()
    await middlewarePatterns()
    await requestTemplates()
    await dynamicRequestGeneration()
    await advancedBodyHandling()
    await conditionalAndCompositeComponents()
    await productionReadyPatterns()
  }

  // MARK: - Complex DSL Composition

  /// Demonstrates complex DSL patterns with nested components and conditional logic
  ///
  /// Shows advanced request building techniques including:
  /// - Multi-level conditional components
  /// - Complex header management with validation
  /// - Dynamic query parameter construction
  /// - Request validation and error handling
  /// - Performance optimization patterns
  public static func complexDSLPatterns() async {
    print("🔹 Complex DSL Composition Patterns")

    do {
      let client = NetworkClient()

      // Example 1: Multi-tier API request with complex business logic
      struct APIRequestContext {
        let environment: Environment
        let userRole: UserRole
        let features: Set<String>
        let locale: Locale
        let debugMode: Bool
        let requestId: UUID

        enum Environment: String {
          case development = "dev"
          case staging = "staging"
          case production = "prod"

          var baseURL: String {
            switch self {
            case .development: return "https://dev-api.example.com"
            case .staging: return "https://staging-api.example.com"
            case .production: return "https://api.example.com"
            }
          }

          var apiVersion: String {
            switch self {
            case .development, .staging: return "v2-beta"
            case .production: return "v2"
            }
          }
        }

        enum UserRole: String, CaseIterable {
          case guest, user, premium, admin

          var permissions: Set<String> {
            switch self {
            case .guest: return ["read:public"]
            case .user: return ["read:public", "read:profile", "write:profile"]
            case .premium: return ["read:public", "read:profile", "write:profile", "read:premium"]
            case .admin: return ["read:all", "write:all", "admin:manage"]
            }
          }
        }
      }

      let context = APIRequestContext(
        environment: .staging,
        userRole: .premium,
        features: ["analytics", "push_notifications", "dark_mode", "premium_content"],
        locale: Locale(identifier: "en_US"),
        debugMode: true,
        requestId: UUID()
      )

      // Complex request with multiple conditional layers
      let complexRequest = try RequestBuilder.build {
        GET("/\(context.environment.apiVersion)/user/dashboard")
        RequestBaseURL(context.environment.baseURL)

        // Core identification headers
        Header("X-Request-ID", context.requestId.uuidString)
        Header("X-Client-Version", "2.1.0")
        Header("X-Platform", "iOS")
        Header("X-Environment", context.environment.rawValue)

        // User context headers
        Header("X-User-Role", context.userRole.rawValue)
        Header("X-User-Permissions", context.userRole.permissions.sorted().joined(separator: ","))

        // Localization
        AcceptHeader(.json)
        Header("Accept-Language", context.locale.identifier)
        Header("X-Timezone", TimeZone.current.identifier)

        // Feature flags as conditional components
        for feature in context.features.sorted() {
          ConditionalComponent(
            context.features.contains(feature),
            Header(
              "X-Feature-\(feature.replacingOccurrences(of: "_", with: "-"))",
              "enabled"
            )
          )
        }

        // Environment-specific configurations
        if context.environment != .production {
          // Non-production environments get debug headers
          Header("X-Debug-Mode", "true")
          Header("X-Test-Environment", "true")
          RequestTimeout(.seconds(60))  // Longer timeout for testing

          if context.debugMode {
            Header("X-Verbose-Logging", "true")
            Header("X-Performance-Metrics", "enabled")
          }
        } else {
          // Production optimizations
          RequestTimeout(.seconds(30))
          Header("X-Cache-Control", "max-age=300")
        }

        // Role-based query parameters
        switch context.userRole {
        case .guest:
          QueryParams([
            "view": "public",
            "limit": "10",
          ])

        case .user:
          QueryParams([
            "view": "user",
            "include": "profile,preferences",
            "limit": "25",
          ])

        case .premium:
          QueryParams([
            "view": "premium",
            "include": "profile,preferences,premium_content,analytics",
            "limit": "50",
            "premium_features": "true",
          ])

        case .admin:
          QueryParams([
            "view": "admin",
            "include": "all",
            "limit": "100",
            "admin_mode": "true",
            "show_hidden": "true",
          ])
        }

        // Conditional caching based on user role
        ConditionalComponent(
          context.userRole == .guest,
          Header("Cache-Control", "public, max-age=600")
        )

        ConditionalComponent(
          condition: context.userRole != .guest,
          component: Header("Cache-Control", "private, no-cache")
        )
      }

      print("   ✅ Complex DSL Request Built:")
      print("      URL: \(complexRequest.url?.absoluteString ?? "nil")")
      print("      Headers: \(complexRequest.headers.count)")
      print("      Environment: \(context.environment.rawValue)")
      print("      User Role: \(context.userRole.rawValue)")
      print("      Features: \(context.features.count)")

      // Example 2: Nested conditional request with validation
      let validationRequest = try RequestBuilder.build {
        POST("/api/v2/data/validate")
        RequestBaseURL("https://api.example.com")

        // Nested conditionals for complex business logic
        ConditionalComponent(
          condition: context.userRole.permissions.contains("write:data"),
          component: CompositeComponent([
            Header("X-Write-Permission", "granted"),
            Header("X-Validation-Level", "strict"),
            ConditionalComponent(
              condition: context.userRole == .admin,
              component: Header("X-Skip-Validation", "false")  // Admins get stricter validation
            ),
          ])
        )

        // Content type with validation
        ContentType(.json)
        AcceptHeader(.json)

        // Security headers for sensitive operations
        Header("X-CSRF-Protection", "enabled")
        Header("X-Content-Type-Options", "nosniff")

        // Mock JSON body
        JSONBody([
          "data": ["key": "value"],
          "metadata": [
            "source": "mobile_app",
            "version": "2.1.0",
            "user_role": context.userRole.rawValue,
          ],
        ])
      }

      print("   ✅ Validation Request Built:")
      print("      Method: \(validationRequest.method)")
      print("      Has Body: \(validationRequest.body != nil)")
      print("      Content-Type: \(validationRequest.headers["Content-Type"] ?? "none")")
    } catch {
      print("   ❌ Complex DSL Error: \(error)")
    }
  }

  // MARK: - Authentication Flows

  /// Demonstrates advanced authentication patterns and flows
  ///
  /// Shows sophisticated authentication handling including:
  /// - Multi-token authentication systems
  /// - Token refresh and rotation patterns
  /// - Credential escalation flows
  /// - Authentication middleware integration
  /// - Secure credential storage patterns
  public static func authenticationFlows() async {
    print("🔹 Advanced Authentication Flow Patterns")

    do {
      let client = NetworkClient()

      // Example 1: Multi-token authentication system
      struct TokenSet {
        let accessToken: String
        let refreshToken: String
        let idToken: String?
        let deviceToken: String?
        let expiresAt: Date
        let tokenType: String
        let scope: Set<String>

        var isExpired: Bool {
          Date() >= expiresAt.addingTimeInterval(-300)  // 5-minute buffer
        }

        var authorizationHeader: String {
          "\(tokenType) \(accessToken)"
        }
      }

      let tokenSet = TokenSet(
        accessToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.access_token_payload",
        refreshToken: "refresh_token_xyz789",
        idToken: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.id_token_payload",
        deviceToken: "device_token_abc123",
        expiresAt: Date().addingTimeInterval(3600),
        tokenType: "Bearer",
        scope: ["read", "write", "admin"]
      )

      let multiTokenRequest = try RequestBuilder.build {
        GET("/api/v2/user/profile")
        RequestBaseURL("https://api.example.com")

        // Primary authentication
        Header("Authorization", tokenSet.authorizationHeader)

        // Conditional additional tokens
        if let idToken = tokenSet.idToken {
          Header("X-ID-Token", idToken)
        }

        if let deviceToken = tokenSet.deviceToken {
          Header("X-Device-Token", deviceToken)
        }

        // Token metadata
        Header("X-Token-Scope", tokenSet.scope.sorted().joined(separator: " "))
        Header("X-Token-Type", tokenSet.tokenType)

        // Security headers
        Header("X-Requested-With", "XMLHttpRequest")
        Header("X-Client-Type", "mobile")

        AcceptHeader(.json)
        RequestTimeout(.seconds(30))
      }

      print("   ✅ Multi-token Request:")
      print("      Token Type: \(tokenSet.tokenType)")
      print("      Scopes: \(tokenSet.scope.joined(separator: ", "))")
      print("      Has ID Token: \(tokenSet.idToken != nil)")
      print("      Has Device Token: \(tokenSet.deviceToken != nil)")

      // Example 2: Credential escalation flow
      enum AuthenticationLevel {
        case basic(username: String, password: String)
        case mfa(basicAuth: (String, String), totpCode: String)
        case certificate(certData: Data, keyData: Data)
        case delegated(impersonateUser: String, adminToken: String)
      }

      let authLevel = AuthenticationLevel.mfa(
        basicAuth: ("user@example.com", "securepassword123"),
        totpCode: "123456"
      )

      let escalatedRequest = try RequestBuilder.build {
        POST("/api/v2/admin/escalate")
        RequestBaseURL("https://api.example.com")

        // Build authentication based on level
        switch authLevel {
        case .basic(let username, let password):
          RequestBasicAuth(username: username, password: password)
          Header("X-Auth-Level", "basic")

        case .mfa(let basicAuth, let totpCode):
          RequestBasicAuth(username: basicAuth.0, password: basicAuth.1)
          Header("X-TOTP-Code", totpCode)
          Header("X-Auth-Level", "mfa")
          Header("X-MFA-Method", "totp")

        case .certificate(let certData, let keyData):
          Header("X-Client-Cert", certData.base64EncodedString())
          Header("X-Client-Key-Hash", keyData.sha256Hash)
          Header("X-Auth-Level", "certificate")

        case .delegated(let impersonateUser, let adminToken):
          BearerAuth(adminToken)
          Header("X-Impersonate-User", impersonateUser)
          Header("X-Auth-Level", "delegated")
          Header("X-Admin-Action", "user_impersonation")
        }

        // Common security headers
        Header("X-CSRF-Token", UUID().uuidString)
        Header("X-Request-Source", "mobile_app")

        ContentType(.json)
        AcceptHeader(.json)

        JSONBody([
          "action": "request_elevated_access",
          "reason": "administrative_task",
          "duration_minutes": 60,
        ])
      }

      print("   ✅ Credential Escalation Request Built")

      // Example 3: Token refresh flow with retry logic
      class AdvancedTokenManager {
        private var currentTokens: TokenSet
        private let refreshEndpoint: String
        private let clientCredentials: (id: String, secret: String)
        private let lock = NSLock()

        init(tokens: TokenSet, refreshEndpoint: String, clientId: String, clientSecret: String) {
          self.currentTokens = tokens
          self.refreshEndpoint = refreshEndpoint
          self.clientCredentials = (id: clientId, secret: clientSecret)
        }

        func getValidToken() async throws -> TokenSet {
          lock.lock()
          defer { lock.unlock() }

          if !currentTokens.isExpired {
            return currentTokens
          }

          // Refresh tokens
          print("   🔄 Refreshing expired tokens...")
          let newTokens = try await refreshTokens()
          currentTokens = newTokens
          return newTokens
        }

        private func refreshTokens() async throws -> TokenSet {
          let refreshRequest = try RequestBuilder.build {
            POST("/oauth/token")
            RequestBaseURL(refreshEndpoint)

            // Client authentication
            RequestBasicAuth(
              username: clientCredentials.id,
              password: clientCredentials.secret
            )

            ContentType(.formURLEncoded)
            AcceptHeader(.json)

            FormBody([
              "grant_type": "refresh_token",
              "refresh_token": currentTokens.refreshToken,
              "scope": currentTokens.scope.joined(separator: " "),
            ])

            // Security headers for token refresh
            Header("X-Token-Refresh", "true")
            Header("X-Client-Version", "2.1.0")

            RequestTimeout(.seconds(15))
          }

          let client = NetworkClient()
          let response = try await client.execute(refreshRequest)

          // Simulate token parsing (in real app, parse JSON response)
          return TokenSet(
            accessToken: "new_access_token_\(Int.random(in: 1000...9999))",
            refreshToken: currentTokens.refreshToken,  // May be rotated
            idToken: "new_id_token_\(Int.random(in: 1000...9999))",
            deviceToken: currentTokens.deviceToken,
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer",
            scope: currentTokens.scope
          )
        }
      }

      let tokenManager = AdvancedTokenManager(
        tokens: tokenSet,
        refreshEndpoint: "https://auth.example.com",
        clientId: "mobile_app_client",
        clientSecret: "client_secret_123"
      )

      // Use token manager in request
      let refreshedTokens = try await tokenManager.getValidToken()

      let authenticatedRequest = try RequestBuilder.build {
        GET("/api/v2/protected/resource")
        RequestBaseURL("https://api.example.com")

        BearerAuth(refreshedTokens.accessToken)

        // Add token metadata for debugging
        Header("X-Token-Expires", ISO8601DateFormatter().string(from: refreshedTokens.expiresAt))
        Header("X-Token-Scope", refreshedTokens.scope.joined(separator: " "))

        AcceptHeader(.json)
        UserAgent("AdvancedNetworkingApp/2.1.0")
      }

      print("   ✅ Authenticated Request with Token Management:")
      print("      Token Valid: \(!refreshedTokens.isExpired)")
      print("      Expires: \(refreshedTokens.expiresAt)")
    } catch {
      print("   ❌ Authentication Flow Error: \(error)")
    }
  }

  // MARK: - Middleware Integration Patterns

  /// Demonstrates advanced middleware patterns and custom middleware creation
  ///
  /// Shows sophisticated middleware architecture including:
  /// - Custom request transformation middleware
  /// - Response processing pipelines
  /// - Conditional middleware application
  /// - Performance monitoring middleware
  /// - Security enforcement middleware
  public static func middlewarePatterns() async {
    print("🔹 Advanced Middleware Integration Patterns")

    do {
      // Example 1: Request preprocessing middleware with validation
      struct RequestPreprocessingMiddleware: Middleware {
        let requirements: RequestRequirements

        struct RequestRequirements {
          let requiredHeaders: Set<String>
          let maxBodySize: Int
          let allowedMethods: Set<String>
          let rateLimitPerMinute: Int
        }

        func process(
          _ request: HTTPRequest,
          next: @escaping (HTTPRequest) async throws -> HTTPResponse
        ) async throws -> HTTPResponse {
          var processedRequest = request

          // Validate required headers
          for requiredHeader in requirements.requiredHeaders {
            if processedRequest.headers[requiredHeader] == nil {
              print("   ⚠️ Missing required header: \(requiredHeader)")
              // In production, might throw an error or add default value
              processedRequest.headers[requiredHeader] = "default-value"
            }
          }

          // Validate body size
          if let body = processedRequest.body, body.count > requirements.maxBodySize {
            print(
              "   ⚠️ Request body exceeds maximum size: \(body.count) > \(requirements.maxBodySize)"
            )
          }

          // Add processing metadata
          processedRequest.headers["X-Processed-By"] = "RequestPreprocessingMiddleware"
          processedRequest.headers["X-Processing-Time"] = ISO8601DateFormatter().string(
            from: Date()
          )

          print(
            "   🔧 Request preprocessed: \(processedRequest.method) \(processedRequest.url?.path ?? "")"
          )

          return try await next(processedRequest)
        }
      }

      let preprocessingMiddleware = RequestPreprocessingMiddleware(
        requirements: .init(
          requiredHeaders: ["X-Client-ID", "X-API-Version"],
          maxBodySize: 1024 * 1024,  // 1MB
          allowedMethods: ["GET", "POST", "PUT", "DELETE"],
          rateLimitPerMinute: 100
        )
      )

      // Example 2: Response transformation middleware
      struct ResponseTransformationMiddleware: Middleware {
        func process(
          _ request: HTTPRequest,
          next: @escaping (HTTPRequest) async throws -> HTTPResponse
        ) async throws -> HTTPResponse {
          let response = try await next(request)

          // Transform response headers
          var transformedResponse = response

          // Add response metadata
          transformedResponse.headers["X-Response-Processed"] = "true"
          transformedResponse.headers["X-Processing-Node"] = ProcessInfo.processInfo.hostName
          transformedResponse.headers["X-Response-Time"] = ISO8601DateFormatter().string(
            from: Date()
          )

          // Log response metrics
          let responseSize = response.body?.count ?? 0
          print("   📊 Response metrics: \(response.statusCode) (\(responseSize) bytes)")

          // Content type validation
          if let contentType = response.headers["Content-Type"] {
            print("   📋 Response Content-Type validated: \(contentType)")
          }

          return transformedResponse
        }
      }

      // Example 3: Conditional middleware based on request properties
      struct ConditionalSecurityMiddleware: Middleware {
        func process(
          _ request: HTTPRequest,
          next: @escaping (HTTPRequest) async throws -> HTTPResponse
        ) async throws -> HTTPResponse {
          var securedRequest = request

          // Apply security measures based on request characteristics
          let isSecureEndpoint =
            request.url?.path.contains("/api/v2/admin") == true
            || request.url?.path.contains("/api/v2/payment") == true

          if isSecureEndpoint {
            print("   🔐 Applying enhanced security for secure endpoint")

            // Add security headers
            securedRequest.headers["X-Security-Level"] = "enhanced"
            securedRequest.headers["X-CSRF-Protection"] = "enabled"
            securedRequest.headers["X-Frame-Options"] = "DENY"
            securedRequest.headers["X-Content-Type-Options"] = "nosniff"

            // Validate authentication
            if securedRequest.headers["Authorization"] == nil {
              print("   ❌ Security middleware: Missing authentication for secure endpoint")
              throw HTTPError.unauthorized
            }
          }

          // Add common security headers
          securedRequest.headers["X-Security-Scan"] = "completed"

          return try await next(securedRequest)
        }
      }

      // Create client with middleware pipeline
      let client = NetworkClient.Builder()
        .middleware(preprocessingMiddleware)
        .middleware(ConditionalSecurityMiddleware())
        .middleware(ResponseTransformationMiddleware())
        .build()

      // Test request with middleware pipeline
      let middlewareRequest = try RequestBuilder.build {
        GET("/api/v2/admin/users")
        RequestBaseURL("https://api.example.com")

        // Headers that will be validated by middleware
        Header("X-Client-ID", "mobile-app-123")
        Header("X-API-Version", "2.1")

        // Authentication for secure endpoint
        BearerAuth("admin-token-xyz789")

        AcceptHeader(.json)
        UserAgent("AdminApp/2.1.0")
      }

      print("   ✅ Middleware Pipeline Request Built:")
      print("      Target: Admin endpoint (secure)")
      print("      Client-ID: mobile-app-123")
      print("      Has Auth: true")

      // Example 4: Performance monitoring middleware
      struct PerformanceMonitoringMiddleware: Middleware {
        func process(
          _ request: HTTPRequest,
          next: @escaping (HTTPRequest) async throws -> HTTPResponse
        ) async throws -> HTTPResponse {
          let startTime = CFAbsoluteTimeGetCurrent()
          let requestId = UUID().uuidString

          print("   📡 Starting request \(requestId): \(request.method) \(request.url?.path ?? "")")

          // Add monitoring headers
          var monitoredRequest = request
          monitoredRequest.headers["X-Trace-ID"] = requestId
          monitoredRequest.headers["X-Start-Time"] = "\(startTime)"

          do {
            let response = try await next(monitoredRequest)
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = (endTime - startTime) * 1000  // Convert to milliseconds

            print("   ⏱️ Request \(requestId) completed in \(String(format: "%.2f", duration))ms")
            print("   📊 Status: \(response.statusCode), Size: \(response.body?.count ?? 0) bytes")

            // Add performance headers to response
            var performanceResponse = response
            performanceResponse.headers["X-Response-Time"] = "\(String(format: "%.2f", duration))ms"
            performanceResponse.headers["X-Trace-ID"] = requestId

            return performanceResponse
          } catch {
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = (endTime - startTime) * 1000

            print(
              "   ❌ Request \(requestId) failed after \(String(format: "%.2f", duration))ms: \(error)"
            )
            throw error
          }
        }
      }

      let performanceClient = NetworkClient.Builder()
        .middleware(PerformanceMonitoringMiddleware())
        .build()

      let monitoredRequest = try RequestBuilder.build {
        GET("/api/v2/status")
        RequestBaseURL("https://httpbin.org")

        AcceptHeader(.json)
        RequestTimeout(.seconds(10))
      }

      print("   ✅ Performance Monitoring Middleware Configured")
    } catch {
      print("   ❌ Middleware Pattern Error: \(error)")
    }
  }

  // MARK: - Request Templates

  /// Demonstrates reusable request templates for common API patterns
  ///
  /// Shows advanced template creation including:
  /// - Parameterized request builders
  /// - API-specific request factories
  /// - Template composition and inheritance
  /// - Configuration-driven template generation
  /// - Template validation and error handling
  public static func requestTemplates() async {
    print("🔹 Advanced Request Template Patterns")

    do {
      // Example 1: API-specific request template factory
      struct GitHubAPITemplate {
        let baseURL: String
        let apiVersion: String
        let authToken: String?
        let userAgent: String

        init(
          baseURL: String = "https://api.github.com",
          apiVersion: String = "v3",
          authToken: String? = nil,
          userAgent: String = "AdvancedNetworkingApp/2.1.0"
        ) {
          self.baseURL = baseURL
          self.apiVersion = apiVersion
          self.authToken = authToken
          self.userAgent = userAgent
        }

        func buildRequest(
          method: String = "GET",
          endpoint: String,
          queryParams: [String: String] = [:],
          additionalHeaders: [String: String] = [:],
          body: Data? = nil
        ) throws -> [any RequestComponent] {
          var components: [any RequestComponent] = []

          // Add HTTP method component dynamically
          switch method.uppercased() {
          case "GET": components.append(GET(endpoint))
          case "POST": components.append(POST(endpoint))
          case "PUT": components.append(PUT(endpoint))
          case "DELETE": components.append(DELETE(endpoint))
          case "PATCH": components.append(PATCH(endpoint))
          default: components.append(GET(endpoint))
          }

          // Base configuration
          components.append(RequestBaseURL(baseURL))
          components.append(AcceptHeader(.json))
          components.append(UserAgent(userAgent))
          components.append(Header("X-GitHub-Api-Version", "2022-11-28"))

          // Authentication
          if let token = authToken {
            components.append(BearerAuth(token))
          }

          // Query parameters
          if !queryParams.isEmpty {
            components.append(QueryParams(queryParams))
          }

          // Additional headers
          for (key, value) in additionalHeaders {
            components.append(Header(key, value))
          }

          // Body
          if let bodyData = body {
            components.append(ContentType(.json))
            components.append(DataBody(bodyData))
          }

          // Rate limiting headers
          components.append(Header("X-RateLimit-Aware", "true"))

          return components
        }

        func userRequest(username: String) throws -> [any RequestComponent] {
          try buildRequest(
            endpoint: "/users/\(username)",
            additionalHeaders: [
              "X-GitHub-Media-Type": "github.v3+json",
              "X-Request-Type": "user_profile",
            ]
          )
        }

        func repositoriesRequest(
          username: String,
          page: Int = 1,
          perPage: Int = 30
        ) throws -> [any RequestComponent] {
          try buildRequest(
            endpoint: "/users/\(username)/repos",
            queryParams: [
              "type": "all",
              "sort": "updated",
              "direction": "desc",
              "page": "\(page)",
              "per_page": "\(perPage)",
            ],
            additionalHeaders: [
              "X-Request-Type": "repository_list"
            ]
          )
        }

        func createIssueRequest(
          owner: String,
          repo: String,
          title: String,
          body: String,
          labels: [String] = [],
          assignees: [String] = []
        ) throws -> [any RequestComponent] {
          let issueData: [String: Any] = [
            "title": title,
            "body": body,
            "labels": labels,
            "assignees": assignees,
          ]

          let jsonData = try JSONSerialization.data(withJSONObject: issueData)

          return try buildRequest(
            method: "POST",
            endpoint: "/repos/\(owner)/\(repo)/issues",
            additionalHeaders: [
              "X-Request-Type": "issue_creation"
            ],
            body: jsonData
          )
        }
      }

      let githubTemplate = GitHubAPITemplate(
        authToken: ProcessInfo.processInfo.environment["GITHUB_TOKEN"] ?? "demo-token",
        userAgent: "AdvancedRequestBuilding/1.0"
      )

      // Use GitHub template
      let userRequest = try RequestBuilder.build {
        try githubTemplate.userRequest(username: "octocat")
      }

      let reposRequest = try RequestBuilder.build {
        try githubTemplate.repositoriesRequest(username: "octocat", page: 1, perPage: 10)
      }

      print("   ✅ GitHub API Template:")
      print("      User Request: \(userRequest.url?.path ?? "")")
      print("      Repos Request: \(reposRequest.url?.path ?? "")")
      print(
        "      Query Params: \(reposRequest.url?.query?.components(separatedBy: "&").count ?? 0)"
      )

      // Example 2: REST API template with CRUD operations
      struct RESTAPITemplate<T: Codable & Sendable> {
        let baseURL: String
        let resourcePath: String
        let authToken: String?
        let apiVersion: String

        func listRequest(
          page: Int = 1,
          limit: Int = 20,
          filters: [String: String] = [:],
          sorting: (field: String, direction: String)? = nil
        ) throws -> [any RequestComponent] {
          var queryParams = [
            "page": "\(page)",
            "limit": "\(limit)",
          ]

          // Add filters
          for (key, value) in filters {
            queryParams["filter[\(key)]"] = value
          }

          // Add sorting
          if let sort = sorting {
            queryParams["sort"] = "\(sort.field):\(sort.direction)"
          }

          return [
            GET("/\(apiVersion)/\(resourcePath)"),
            RequestBaseURL(baseURL),
            QueryParams(queryParams),
            AcceptHeader(.json),
            authToken.map { BearerAuth($0) } as Any,
            Header("X-Operation", "list"),
            RequestTimeout(.seconds(30)),
          ].compactMap { $0 as? any RequestComponent }
        }

        func getRequest(id: String, include: [String] = []) throws -> [any RequestComponent] {
          var components: [any RequestComponent] = [
            GET("/\(apiVersion)/\(resourcePath)/\(id)"),
            RequestBaseURL(baseURL),
            AcceptHeader(.json),
            Header("X-Operation", "get"),
            RequestTimeout(.seconds(30)),
          ]

          if let token = authToken {
            components.append(BearerAuth(token))
          }

          if !include.isEmpty {
            components.append(QueryParams(["include": include.joined(separator: ",")]))
          }

          return components
        }

        func createRequest(data: T) throws -> [any RequestComponent] {
          let jsonData = try JSONEncoder().encode(data)

          return [
            POST("/\(apiVersion)/\(resourcePath)"),
            RequestBaseURL(baseURL),
            ContentType(.json),
            AcceptHeader(.json),
            DataBody(jsonData),
            authToken.map { BearerAuth($0) } as Any,
            Header("X-Operation", "create"),
            Header("X-Idempotency-Key", UUID().uuidString),
            RequestTimeout(.seconds(60)),
          ].compactMap { $0 as? any RequestComponent }
        }

        func updateRequest(id: String, data: T) throws -> [any RequestComponent] {
          let jsonData = try JSONEncoder().encode(data)

          return [
            PUT("/\(apiVersion)/\(resourcePath)/\(id)"),
            RequestBaseURL(baseURL),
            ContentType(.json),
            AcceptHeader(.json),
            DataBody(jsonData),
            authToken.map { BearerAuth($0) } as Any,
            Header("X-Operation", "update"),
            Header("X-Idempotency-Key", UUID().uuidString),
            RequestTimeout(.seconds(60)),
          ].compactMap { $0 as? any RequestComponent }
        }

        func deleteRequest(id: String) throws -> [any RequestComponent] {
          [
            DELETE("/\(apiVersion)/\(resourcePath)/\(id)"),
            RequestBaseURL(baseURL),
            AcceptHeader(.json),
            authToken.map { BearerAuth($0) } as Any,
            Header("X-Operation", "delete"),
            Header("X-Confirmation", "true"),
            RequestTimeout(.seconds(30)),
          ].compactMap { $0 as? any RequestComponent }
        }
      }

      // Example usage with User model
      struct User: Codable, Sendable {
        let id: String?
        let name: String
        let email: String
        let role: String
      }

      let userAPITemplate = RESTAPITemplate<User>(
        baseURL: "https://api.example.com",
        resourcePath: "users",
        authToken: "api-token-xyz789",
        apiVersion: "v2"
      )

      let listUsersRequest = try RequestBuilder.build {
        try userAPITemplate.listRequest(
          page: 1,
          limit: 50,
          filters: ["role": "admin", "status": "active"],
          sorting: (field: "created_at", direction: "desc")
        )
      }

      let createUserRequest = try RequestBuilder.build {
        try userAPITemplate.createRequest(
          data: User(
            id: nil,
            name: "John Doe",
            email: "john.doe@example.com",
            role: "user"
          )
        )
      }

      print("   ✅ REST API Template:")
      print("      List Users: \(listUsersRequest.url?.absoluteString ?? "")")
      print("      Create User: \(createUserRequest.method) \(createUserRequest.url?.path ?? "")")
      print("      Has Auth: \(createUserRequest.headers["Authorization"] != nil)")
    } catch {
      print("   ❌ Request Template Error: \(error)")
    }
  }

  // MARK: - Dynamic Request Generation

  /// Demonstrates data-driven request construction and dynamic request generation
  ///
  /// Shows advanced dynamic request building including:
  /// - Configuration-driven request generation
  /// - Data model to request mapping
  /// - Bulk request generation from data sets
  /// - Template-based dynamic construction
  /// - Runtime request modification
  public static func dynamicRequestGeneration() async {
    print("🔹 Dynamic Request Generation Patterns")

    do {
      // Example 1: Configuration-driven request builder
      struct RequestConfiguration: Codable {
        let method: String
        let endpoint: String
        let baseURL: String
        let headers: [String: String]
        let queryParams: [String: String]
        let timeout: TimeInterval
        let authentication: AuthConfig?
        let body: BodyConfig?

        struct AuthConfig: Codable {
          let type: String  // "bearer", "basic", "apikey"
          let token: String?
          let username: String?
          let password: String?
          let keyHeader: String?
          let keyValue: String?
        }

        struct BodyConfig: Codable {
          let type: String  // "json", "form", "raw"
          let data: [String: String]
        }
      }

      func buildRequestFromConfiguration(_ config: RequestConfiguration) throws -> HTTPRequest {
        try RequestBuilder.build {
          // Dynamic method selection
          switch config.method.uppercased() {
          case "GET": GET(config.endpoint)
          case "POST": POST(config.endpoint)
          case "PUT": PUT(config.endpoint)
          case "DELETE": DELETE(config.endpoint)
          case "PATCH": PATCH(config.endpoint)
          default: GET(config.endpoint)
          }

          RequestBaseURL(config.baseURL)
          RequestTimeout(.seconds(config.timeout))

          // Dynamic headers
          for (key, value) in config.headers {
            Header(key, value)
          }

          // Dynamic query parameters
          if !config.queryParams.isEmpty {
            QueryParams(config.queryParams)
          }

          // Dynamic authentication
          if let auth = config.authentication {
            switch auth.type {
            case "bearer":
              if let token = auth.token {
                BearerAuth(token)
              }

            case "basic":
              if let username = auth.username, let password = auth.password {
                RequestBasicAuth(username: username, password: password)
              }

            case "apikey":
              if let header = auth.keyHeader, let value = auth.keyValue {
                APIKey(key: value, headerName: header)
              }

            default:
              EmptyComponent()
            }
          }

          // Dynamic body
          if let bodyConfig = config.body {
            switch bodyConfig.type {
            case "json":
              ContentType(.json)
              let jsonData = try JSONSerialization.data(withJSONObject: bodyConfig.data)
              DataBody(jsonData)

            case "form":
              ContentType(.formURLEncoded)
              FormBody(bodyConfig.data)

            case "raw":
              if let rawData = bodyConfig.data["content"]?.data(using: .utf8) {
                DataBody(rawData)
              }

            default:
              EmptyComponent()
            }
          }
        }
      }

      // Sample configuration
      let sampleConfig = RequestConfiguration(
        method: "POST",
        endpoint: "/api/v2/analytics/events",
        baseURL: "https://analytics.example.com",
        headers: [
          "X-Client-Version": "2.1.0",
          "X-Platform": "iOS",
          "X-Session-ID": UUID().uuidString,
        ],
        queryParams: [
          "version": "2",
          "format": "json",
        ],
        timeout: 30.0,
        authentication: RequestConfiguration.AuthConfig(
          type: "bearer",
          token: "analytics-token-abc123",
          username: nil,
          password: nil,
          keyHeader: nil,
          keyValue: nil
        ),
        body: RequestConfiguration.BodyConfig(
          type: "json",
          data: [
            "event_type": "user_action",
            "user_id": "user123",
            "action": "button_tap",
            "timestamp": "\(Int(Date().timeIntervalSince1970))",
          ]
        )
      )

      let configBasedRequest = try buildRequestFromConfiguration(sampleConfig)
      print("   ✅ Configuration-driven Request:")
      print("      Method: \(configBasedRequest.method)")
      print("      URL: \(configBasedRequest.url?.absoluteString ?? "")")
      print("      Headers: \(configBasedRequest.headers.count)")

      // Example 2: Bulk request generation from data models
      struct APIEndpoint {
        let name: String
        let method: String
        let path: String
        let requiresAuth: Bool
        let rateLimit: Int
        let timeout: TimeInterval
        let cacheability: String
      }

      let apiEndpoints = [
        APIEndpoint(
          name: "users",
          method: "GET",
          path: "/users",
          requiresAuth: true,
          rateLimit: 100,
          timeout: 30,
          cacheability: "public"
        ),
        APIEndpoint(
          name: "posts",
          method: "GET",
          path: "/posts",
          requiresAuth: false,
          rateLimit: 200,
          timeout: 15,
          cacheability: "public"
        ),
        APIEndpoint(
          name: "profile",
          method: "GET",
          path: "/profile",
          requiresAuth: true,
          rateLimit: 50,
          timeout: 20,
          cacheability: "private"
        ),
        APIEndpoint(
          name: "settings",
          method: "PUT",
          path: "/settings",
          requiresAuth: true,
          rateLimit: 10,
          timeout: 60,
          cacheability: "no-cache"
        ),
      ]

      let bulkRequests = try apiEndpoints.map { endpoint in
        try RequestBuilder.build {
          switch endpoint.method {
          case "GET": GET(endpoint.path)
          case "POST": POST(endpoint.path)
          case "PUT": PUT(endpoint.path)
          case "DELETE": DELETE(endpoint.path)
          default: GET(endpoint.path)
          }

          RequestBaseURL("https://api.example.com/v2")
          RequestTimeout(.seconds(endpoint.timeout))

          // Common headers
          Header("X-API-Endpoint", endpoint.name)
          Header("X-Rate-Limit", "\(endpoint.rateLimit)")
          Header("Cache-Control", endpoint.cacheability)

          // Conditional authentication
          if endpoint.requiresAuth {
            BearerAuth("user-token-xyz789")
            Header("X-Auth-Required", "true")
          }

          AcceptHeader(.json)
          UserAgent("BulkRequestClient/1.0")
        }
      }

      print("   ✅ Bulk Request Generation:")
      print("      Generated \(bulkRequests.count) requests from endpoint definitions")
      for (index, request) in bulkRequests.enumerated() {
        let endpoint = apiEndpoints[index]
        print(
          "      \(endpoint.name): \(request.method) \(request.url?.path ?? "") (auth: \(endpoint.requiresAuth))"
        )
      }

      // Example 3: Template-based request generation with inheritance
      protocol RequestTemplate {
        func buildComponents() throws -> [any RequestComponent]
      }

      struct BaseAPITemplate: RequestTemplate {
        let baseURL: String
        let version: String
        let authToken: String?

        func buildComponents() throws -> [any RequestComponent] {
          var components: [any RequestComponent] = [
            RequestBaseURL(baseURL),
            Header("X-API-Version", version),
            AcceptHeader(.json),
            UserAgent("TemplateBasedClient/1.0"),
            RequestTimeout(.seconds(30)),
          ]

          if let token = authToken {
            components.append(BearerAuth(token))
          }

          return components
        }
      }

      struct UserAPITemplate: RequestTemplate {
        let base: BaseAPITemplate
        let userId: String?

        func buildComponents() throws -> [any RequestComponent] {
          var components = try base.buildComponents()

          components.append(contentsOf: [
            Header("X-Resource-Type", "user"),
            Header("X-User-Context", userId ?? "anonymous"),
          ])

          if let id = userId {
            components.append(Header("X-User-ID", id))
          }

          return components
        }
      }

      struct AdminAPITemplate: RequestTemplate {
        let user: UserAPITemplate
        let adminRole: String

        func buildComponents() throws -> [any RequestComponent] {
          var components = try user.buildComponents()

          components.append(contentsOf: [
            Header("X-Admin-Role", adminRole),
            Header("X-Elevated-Access", "true"),
            Header("X-Audit-Trail", "enabled"),
          ])

          return components
        }
      }

      // Use template inheritance
      let baseTemplate = BaseAPITemplate(
        baseURL: "https://api.example.com",
        version: "2.1",
        authToken: "base-token-123"
      )

      let userTemplate = UserAPITemplate(
        base: baseTemplate,
        userId: "user123"
      )

      let adminTemplate = AdminAPITemplate(
        user: userTemplate,
        adminRole: "super_admin"
      )

      let templateBasedRequest = try RequestBuilder.build {
        GET("/admin/users/manage")
        try adminTemplate.buildComponents()
      }

      print("   ✅ Template-based Request with Inheritance:")
      print("      URL: \(templateBasedRequest.url?.absoluteString ?? "")")
      print("      Headers: \(templateBasedRequest.headers.count)")
      print("      Admin Role: \(templateBasedRequest.headers["X-Admin-Role"] ?? "none")")
      print("      User Context: \(templateBasedRequest.headers["X-User-Context"] ?? "none")")
    } catch {
      print("   ❌ Dynamic Request Generation Error: \(error)")
    }
  }

  // MARK: - Advanced Body Handling

  /// Demonstrates advanced body handling patterns with different content types
  ///
  /// Shows sophisticated body management including:
  /// - Custom JSON encoding with validation
  /// - Multi-part form data construction
  /// - Binary data handling and streaming
  /// - Content compression and encoding
  /// - Body transformation and validation
  public static func advancedBodyHandling() async {
    print("🔹 Advanced Body Handling Patterns")

    do {
      let client = NetworkClient()

      // Example 1: Advanced JSON body with custom encoding
      struct UserRegistration: Codable {
        let username: String
        let email: String
        let profile: UserProfile
        let preferences: UserPreferences
        let metadata: [String: String]

        struct UserProfile: Codable {
          let firstName: String
          let lastName: String
          let dateOfBirth: Date
          let phoneNumber: String?
          let address: Address?

          struct Address: Codable {
            let street: String
            let city: String
            let state: String
            let zipCode: String
            let country: String
          }
        }

        struct UserPreferences: Codable {
          let theme: String
          let notifications: NotificationSettings
          let privacy: PrivacySettings

          struct NotificationSettings: Codable {
            let email: Bool
            let push: Bool
            let sms: Bool
            let marketing: Bool
          }

          struct PrivacySettings: Codable {
            let profileVisibility: String
            let dataSharing: Bool
            let analytics: Bool
          }
        }
      }

      let userRegistration = UserRegistration(
        username: "johndoe123",
        email: "john.doe@example.com",
        profile: UserRegistration.UserProfile(
          firstName: "John",
          lastName: "Doe",
          dateOfBirth: Date().addingTimeInterval(-86_400 * 365 * 25),  // 25 years ago
          phoneNumber: "+1234567890",
          address: UserRegistration.UserProfile.Address(
            street: "123 Main St",
            city: "New York",
            state: "NY",
            zipCode: "10001",
            country: "USA"
          )
        ),
        preferences: UserRegistration.UserPreferences(
          theme: "dark",
          notifications: UserRegistration.UserPreferences.NotificationSettings(
            email: true,
            push: true,
            sms: false,
            marketing: false
          ),
          privacy: UserRegistration.UserPreferences.PrivacySettings(
            profileVisibility: "friends",
            dataSharing: false,
            analytics: true
          )
        ),
        metadata: [
          "registration_source": "mobile_app",
          "referral_code": "FRIEND123",
          "campaign_id": "summer2024",
        ]
      )

      // Custom JSON encoder with specific formatting
      let jsonEncoder = JSONEncoder()
      jsonEncoder.dateEncodingStrategy = .iso8601
      jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]

      let registrationRequest = try RequestBuilder.build {
        POST("/api/v2/users/register")
        RequestBaseURL("https://api.example.com")

        // Advanced JSON body with custom encoding
        ContentType(.json)
        AcceptHeader(.json)

        let jsonData = try jsonEncoder.encode(userRegistration)
        DataBody(jsonData)

        // Request metadata
        Header("X-Registration-Type", "full")
        Header("X-Content-Length", "\(jsonData.count)")
        Header("X-Encoding", "utf-8")
        Header("X-JSON-Schema-Version", "2.1")

        // Security and validation headers
        Header("X-CSRF-Token", UUID().uuidString)
        Header("X-Request-Hash", jsonData.sha256Hash)

        BearerAuth("registration-token-abc123")
        RequestTimeout(.seconds(60))  // Longer timeout for complex registration
      }

      print("   ✅ Advanced JSON Body Request:")
      print("      Body Size: \(registrationRequest.body?.count ?? 0) bytes")
      print("      Content-Type: \(registrationRequest.headers["Content-Type"] ?? "none")")
      print(
        "      JSON Schema Version: \(registrationRequest.headers["X-JSON-Schema-Version"] ?? "none")"
      )

      // Example 2: Multi-part form data with file uploads
      struct MultiPartFormData {
        struct Part {
          let name: String
          let data: Data
          let contentType: String?
          let filename: String?
        }

        let boundary: String
        let parts: [Part]

        init(parts: [Part]) {
          self.boundary = "Boundary-\(UUID().uuidString)"
          self.parts = parts
        }

        func buildBody() -> Data {
          var body = Data()

          for part in parts {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)

            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let filename = part.filename {
              disposition += "; filename=\"\(filename)\""
            }
            body.append("\(disposition)\r\n".data(using: .utf8)!)

            if let contentType = part.contentType {
              body.append("Content-Type: \(contentType)\r\n".data(using: .utf8)!)
            }

            body.append("\r\n".data(using: .utf8)!)
            body.append(part.data)
            body.append("\r\n".data(using: .utf8)!)
          }

          body.append("--\(boundary)--\r\n".data(using: .utf8)!)
          return body
        }

        var contentType: String {
          "multipart/form-data; boundary=\(boundary)"
        }
      }

      // Create multi-part form with file upload simulation
      let formData = MultiPartFormData(parts: [
        MultiPartFormData.Part(
          name: "user_id",
          data: "user123".data(using: .utf8)!,
          contentType: nil,
          filename: nil
        ),
        MultiPartFormData.Part(
          name: "description",
          data: "Profile picture update".data(using: .utf8)!,
          contentType: nil,
          filename: nil
        ),
        MultiPartFormData.Part(
          name: "profile_image",
          data: "fake-image-data-here".data(using: .utf8)!,  // Simulate image data
          contentType: "image/jpeg",
          filename: "profile.jpg"
        ),
        MultiPartFormData.Part(
          name: "document",
          data: "fake-pdf-document-data".data(using: .utf8)!,  // Simulate PDF data
          contentType: "application/pdf",
          filename: "verification.pdf"
        ),
      ])

      let multiPartRequest = try RequestBuilder.build {
        POST("/api/v2/users/upload")
        RequestBaseURL("https://api.example.com")

        Header("Content-Type", formData.contentType)
        AcceptHeader(.json)

        let formBody = formData.buildBody()
        DataBody(formBody)

        // Upload-specific headers
        Header("X-Upload-Type", "profile_update")
        Header("X-File-Count", "\(formData.parts.filter { $0.filename != nil }.count)")
        Header("X-Total-Size", "\(formBody.count)")

        BearerAuth("upload-token-xyz789")
        RequestTimeout(.seconds(120))  // Longer timeout for file uploads
      }

      print("   ✅ Multi-part Form Data Request:")
      print("      Boundary: \(formData.boundary)")
      print("      Parts: \(formData.parts.count)")
      print("      Files: \(formData.parts.filter { $0.filename != nil }.count)")
      print("      Total Size: \(multiPartRequest.body?.count ?? 0) bytes")

      // Example 3: Binary data handling with compression
      struct BinaryDataHandler {
        static func compressData(_ data: Data) -> Data {
          // Simulate compression (in real app, use proper compression)
          let compressionRatio = 0.7
          let compressedSize = Int(Double(data.count) * compressionRatio)
          return Data(repeating: 0x42, count: compressedSize)
        }

        static func createChecksum(_ data: Data) -> String {
          // Simulate checksum calculation
          data.sha256Hash.prefix(16).description
        }
      }

      let originalData = Data(repeating: 0x41, count: 1024 * 1024)  // 1MB of 'A's
      let compressedData = BinaryDataHandler.compressData(originalData)
      let checksum = BinaryDataHandler.createChecksum(originalData)

      let binaryDataRequest = try RequestBuilder.build {
        PUT("/api/v2/data/binary")
        RequestBaseURL("https://api.example.com")

        ContentType("application/octet-stream")
        AcceptHeader(.json)

        DataBody(compressedData)

        // Binary data headers
        Header("Content-Encoding", "custom-compression")
        Header("X-Original-Size", "\(originalData.count)")
        Header("X-Compressed-Size", "\(compressedData.count)")
        Header(
          "X-Compression-Ratio",
          String(format: "%.2f", Double(compressedData.count) / Double(originalData.count))
        )
        Header("X-Content-Checksum", checksum)
        Header("X-Data-Type", "binary-blob")

        BearerAuth("binary-upload-token")
        RequestTimeout(.seconds(180))  // Long timeout for large binary data
      }

      print("   ✅ Binary Data Request:")
      print("      Original Size: \(originalData.count) bytes")
      print("      Compressed Size: \(compressedData.count) bytes")
      print(
        "      Compression Ratio: \(String(format: "%.2f", Double(compressedData.count) / Double(originalData.count)))"
      )
      print("      Checksum: \(checksum)")

      // Example 4: Streaming body with chunked transfer
      struct StreamingBody {
        let chunkSize: Int
        let totalSize: Int

        func generateChunks() -> AsyncSequence<Data, Never> {
          AsyncStream { continuation in
            Task {
              var bytesGenerated = 0

              while bytesGenerated < totalSize {
                let remainingBytes = totalSize - bytesGenerated
                let currentChunkSize = min(chunkSize, remainingBytes)

                let chunk = Data(repeating: UInt8(bytesGenerated % 256), count: currentChunkSize)
                continuation.yield(chunk)

                bytesGenerated += currentChunkSize

                // Simulate streaming delay
                try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
              }

              continuation.finish()
            }
          }
        }
      }

      let streamingBody = StreamingBody(chunkSize: 8192, totalSize: 65_536)  // 64KB in 8KB chunks

      // For demonstration, we'll collect the streaming data
      var streamedData = Data()
      for await chunk in streamingBody.generateChunks() {
        streamedData.append(chunk)
      }

      let streamingRequest = try RequestBuilder.build {
        POST("/api/v2/data/stream")
        RequestBaseURL("https://api.example.com")

        ContentType("application/octet-stream")
        Header("Transfer-Encoding", "chunked")
        Header("X-Stream-Chunks", "\(streamingBody.totalSize / streamingBody.chunkSize)")
        Header("X-Chunk-Size", "\(streamingBody.chunkSize)")

        DataBody(streamedData)

        BearerAuth("streaming-token")
        RequestTimeout(.seconds(300))  // Long timeout for streaming
      }

      print("   ✅ Streaming Body Request:")
      print("      Total Size: \(streamingBody.totalSize) bytes")
      print("      Chunk Size: \(streamingBody.chunkSize) bytes")
      print("      Chunks: \(streamingBody.totalSize / streamingBody.chunkSize)")
      print("      Streamed Data: \(streamedData.count) bytes")
    } catch {
      print("   ❌ Advanced Body Handling Error: \(error)")
    }
  }

  // MARK: - Conditional and Composite Components

  /// Demonstrates advanced conditional logic and component composition
  ///
  /// Shows sophisticated component management including:
  /// - Complex conditional component trees
  /// - Dynamic component composition
  /// - Environment-based component selection
  /// - Feature flag integration
  /// - Composite component patterns
  public static func conditionalAndCompositeComponents() async {
    print("🔹 Conditional and Composite Component Patterns")

    do {
      // Example 1: Feature flag driven request composition
      struct FeatureFlags {
        let enableAnalytics: Bool
        let enablePushNotifications: Bool
        let enableBetaFeatures: Bool
        let enableAdvancedLogging: Bool
        let enableRateLimiting: Bool
        let enableCaching: Bool
        let enableCompression: Bool

        static let development = Self(
          enableAnalytics: true,
          enablePushNotifications: true,
          enableBetaFeatures: true,
          enableAdvancedLogging: true,
          enableRateLimiting: false,
          enableCaching: false,
          enableCompression: false
        )

        static let production = Self(
          enableAnalytics: true,
          enablePushNotifications: true,
          enableBetaFeatures: false,
          enableAdvancedLogging: false,
          enableRateLimiting: true,
          enableCaching: true,
          enableCompression: true
        )
      }

      let currentFlags = FeatureFlags.development

      let featureFlagRequest = try RequestBuilder.build {
        POST("/api/v2/user/action")
        RequestBaseURL("https://api.example.com")

        // Conditional analytics components
        ConditionalComponent(
          condition: currentFlags.enableAnalytics,
          component: CompositeComponent([
            Header("X-Analytics-Enabled", "true"),
            Header("X-Tracking-ID", UUID().uuidString),
            Header("X-Session-Start", ISO8601DateFormatter().string(from: Date())),
            QueryParams(["track": "true", "session": UUID().uuidString]),
          ])
        )

        // Conditional push notification support
        ConditionalComponent(
          condition: currentFlags.enablePushNotifications,
          component: CompositeComponent([
            Header("X-Push-Enabled", "true"),
            Header("X-Device-Token", "device-token-123"),
            Header("X-Push-Categories", "alerts,messages,updates"),
          ])
        )

        // Beta features (development only)
        ConditionalComponent(
          condition: currentFlags.enableBetaFeatures,
          component: CompositeComponent([
            Header("X-Beta-User", "true"),
            Header("X-Beta-Features", "advanced_ui,ml_suggestions,voice_commands"),
            Header("X-Experiment-Group", "control"),
            QueryParams(["beta": "true", "experiments": "enabled"]),
          ])
        )

        // Advanced logging (development/staging)
        ConditionalComponent(
          condition: currentFlags.enableAdvancedLogging,
          component: CompositeComponent([
            Header("X-Debug-Level", "verbose"),
            Header("X-Log-Correlation", UUID().uuidString),
            Header("X-Performance-Trace", "enabled"),
            Header("X-Error-Reporting", "detailed"),
          ])
        )

        // Production optimizations
        if currentFlags.enableRateLimiting {
          Header("X-Rate-Limit-Aware", "true")
          Header("X-Client-Priority", "normal")
          RequestTimeout(.seconds(30))
        }

        if currentFlags.enableCaching {
          Header("Cache-Control", "max-age=300")
          Header("X-Cache-Strategy", "aggressive")
        }

        if currentFlags.enableCompression {
          Header("Accept-Encoding", "gzip, deflate, br")
          Header("X-Compression-Preference", "brotli")
        }

        // Common components
        AcceptHeader(.json)
        ContentType(.json)
        BearerAuth("feature-token-xyz789")

        JSONBody([
          "action": "user_interaction",
          "timestamp": Int(Date().timeIntervalSince1970),
          "features": [
            "analytics": currentFlags.enableAnalytics,
            "push": currentFlags.enablePushNotifications,
            "beta": currentFlags.enableBetaFeatures,
          ],
        ])
      }

      print("   ✅ Feature Flag Driven Request:")
      print("      Analytics: \(currentFlags.enableAnalytics)")
      print("      Push Notifications: \(currentFlags.enablePushNotifications)")
      print("      Beta Features: \(currentFlags.enableBetaFeatures)")
      print("      Advanced Logging: \(currentFlags.enableAdvancedLogging)")
      print("      Total Headers: \(featureFlagRequest.headers.count)")

      // Example 2: Environment-based composite components
      enum Environment {
        case development
        case testing
        case staging
        case production

        var debugHeaders: [any RequestComponent] {
          switch self {
          case .development:
            return [
              Header("X-Environment", "development"),
              Header("X-Debug-Mode", "true"),
              Header("X-Verbose-Logging", "true"),
              Header("X-Performance-Monitor", "enabled"),
              Header("X-Error-Detail", "verbose"),
            ]

          case .testing:
            return [
              Header("X-Environment", "testing"),
              Header("X-Test-Mode", "true"),
              Header("X-Mock-Data", "enabled"),
              Header("X-Test-Runner", "automated"),
            ]

          case .staging:
            return [
              Header("X-Environment", "staging"),
              Header("X-Staging-Mode", "true"),
              Header("X-Production-Mirror", "true"),
            ]

          case .production:
            return [
              Header("X-Environment", "production"),
              Header("X-Production-Mode", "true"),
            ]
          }
        }

        var securityHeaders: [any RequestComponent] {
          switch self {
          case .production:
            return [
              Header("Strict-Transport-Security", "max-age=31536000"),
              Header("X-Content-Type-Options", "nosniff"),
              Header("X-Frame-Options", "DENY"),
              Header("X-XSS-Protection", "1; mode=block"),
              Header("Referrer-Policy", "strict-origin-when-cross-origin"),
            ]

          default:
            return [
              Header("X-Security-Level", "development"),
              Header("X-Debug-Security", "relaxed"),
            ]
          }
        }

        var performanceHeaders: [any RequestComponent] {
          switch self {
          case .production:
            return [
              Header("X-Performance-Optimized", "true"),
              Header("Accept-Encoding", "gzip, br"),
              Header("Cache-Control", "max-age=3600"),
            ]

          case .staging:
            return [
              Header("X-Performance-Test", "true"),
              Header("X-Load-Test", "enabled"),
            ]

          default:
            return [
              Header("X-Performance-Debug", "true")
            ]
          }
        }
      }

      let currentEnvironment = Environment.development

      let environmentRequest = try RequestBuilder.build {
        GET("/api/v2/environment/status")
        RequestBaseURL("https://api.example.com")

        // Environment-specific debug components
        CompositeComponent(currentEnvironment.debugHeaders)

        // Environment-specific security components
        CompositeComponent(currentEnvironment.securityHeaders)

        // Environment-specific performance components
        CompositeComponent(currentEnvironment.performanceHeaders)

        // Common components
        AcceptHeader(.json)
        UserAgent("EnvironmentAwareClient/1.0")
        RequestTimeout(.seconds(30))
      }

      print("   ✅ Environment-based Composite Request:")
      print("      Environment: \(currentEnvironment)")
      print("      Debug Headers: \(currentEnvironment.debugHeaders.count)")
      print("      Security Headers: \(currentEnvironment.securityHeaders.count)")
      print("      Performance Headers: \(currentEnvironment.performanceHeaders.count)")

      // Example 3: Complex nested conditional logic
      struct RequestContext {
        let userRole: String
        let subscription: String
        let region: String
        let deviceType: String
        let networkType: String
        let batteryLevel: Float?

        var isPremiumUser: Bool { subscription == "premium" }
        var isAdminUser: Bool { userRole == "admin" }
        var isMobileDevice: Bool { deviceType.contains("mobile") }
        var isLowBattery: Bool { batteryLevel ?? 1.0 < 0.2 }
        var isSlowNetwork: Bool { networkType == "2g" || networkType == "3g" }
      }

      let context = RequestContext(
        userRole: "admin",
        subscription: "premium",
        region: "us-east",
        deviceType: "mobile-ios",
        networkType: "5g",
        batteryLevel: 0.85
      )

      let contextAwareRequest = try RequestBuilder.build {
        POST("/api/v2/context/aware")
        RequestBaseURL("https://api.example.com")

        // User role based headers
        ConditionalComponent(
          condition: context.isAdminUser,
          component: CompositeComponent([
            Header("X-Admin-Access", "granted"),
            Header("X-Admin-Role", context.userRole),
            Header("X-Elevated-Permissions", "true"),
            Header("X-Audit-Log", "enabled"),
          ])
        )

        // Subscription level features
        ConditionalComponent(
          condition: context.isPremiumUser,
          component: CompositeComponent([
            Header("X-Premium-User", "true"),
            Header("X-Subscription-Tier", context.subscription),
            Header("X-Premium-Features", "analytics,priority_support,advanced_api"),
            QueryParams(["premium": "true", "tier": context.subscription]),
          ])
        )

        // Mobile device optimizations
        ConditionalComponent(
          condition: context.isMobileDevice,
          component: CompositeComponent([
            Header("X-Mobile-Client", "true"),
            Header("X-Device-Type", context.deviceType),
            ConditionalComponent(
              condition: context.isLowBattery,
              component: CompositeComponent([
                Header("X-Power-Saving", "enabled"),
                Header("X-Reduce-Payload", "true"),
                Header("X-Battery-Level", "\(context.batteryLevel ?? 0.0)"),
              ])
            ),
          ])
        )

        // Network optimization
        ConditionalComponent(
          condition: context.isSlowNetwork,
          component: CompositeComponent([
            Header("X-Network-Optimization", "enabled"),
            Header("X-Compression", "high"),
            Header("X-Reduce-Images", "true"),
            Header("X-Network-Type", context.networkType),
          ])
        )

        // Regional settings
        Header("X-Region", context.region)
        Header("X-Locale", "en-US")  // Could be derived from region

        AcceptHeader(.json)
        ContentType(.json)
        BearerAuth("context-aware-token")

        JSONBody([
          "context": [
            "user_role": context.userRole,
            "subscription": context.subscription,
            "region": context.region,
            "device_type": context.deviceType,
            "network_type": context.networkType,
            "battery_level": context.batteryLevel ?? 1.0,
          ]
        ])
      }

      print("   ✅ Context-aware Request:")
      print("      User Role: \(context.userRole) (Admin: \(context.isAdminUser))")
      print("      Subscription: \(context.subscription) (Premium: \(context.isPremiumUser))")
      print("      Device: \(context.deviceType) (Mobile: \(context.isMobileDevice))")
      print("      Network: \(context.networkType) (Slow: \(context.isSlowNetwork))")
      print("      Battery: \(context.batteryLevel ?? 1.0) (Low: \(context.isLowBattery))")
      print("      Total Headers: \(contextAwareRequest.headers.count)")
    } catch {
      print("   ❌ Conditional/Composite Component Error: \(error)")
    }
  }

  // MARK: - Production-Ready Patterns

  /// Demonstrates production-ready request building patterns and best practices
  ///
  /// Shows enterprise-grade request construction including:
  /// - Comprehensive error handling and validation
  /// - Security best practices and compliance
  /// - Performance optimization patterns
  /// - Monitoring and observability integration
  /// - Production deployment considerations
  public static func productionReadyPatterns() async {
    print("🔹 Production-Ready Request Building Patterns")

    do {
      // Example 1: Enterprise-grade request with full observability
      struct ProductionRequestBuilder {
        let environment: Environment
        let serviceConfig: ServiceConfiguration
        let securityConfig: SecurityConfiguration
        let observabilityConfig: ObservabilityConfiguration

        enum Environment {
          case production, staging, development
        }

        struct ServiceConfiguration {
          let baseURL: String
          let apiVersion: String
          let serviceVersion: String
          let timeout: TimeInterval
          let retryAttempts: Int
          let rateLimitPerMinute: Int
        }

        struct SecurityConfiguration {
          let enableTLS: Bool
          let certificatePinning: Bool
          let headerSigning: Bool
          let requestEncryption: Bool
          let csrfProtection: Bool
        }

        struct ObservabilityConfiguration {
          let enableMetrics: Bool
          let enableTracing: Bool
          let enableLogging: Bool
          let sampleRate: Double
          let errorReporting: Bool
        }

        func buildEnterpriseRequest(
          method: String,
          endpoint: String,
          body: Data? = nil,
          additionalHeaders: [String: String] = [:]
        ) throws -> HTTPRequest {
          let traceId = UUID().uuidString
          let spanId = UUID().uuidString.prefix(8).description
          let requestId = UUID().uuidString

          return try RequestBuilder.build {
            // HTTP Method
            switch method.uppercased() {
            case "GET": GET(endpoint)
            case "POST": POST(endpoint)
            case "PUT": PUT(endpoint)
            case "DELETE": DELETE(endpoint)
            case "PATCH": PATCH(endpoint)
            default: GET(endpoint)
            }

            // Base configuration
            RequestBaseURL(serviceConfig.baseURL)
            RequestTimeout(.seconds(serviceConfig.timeout))

            // Standard headers
            Header("X-API-Version", serviceConfig.apiVersion)
            Header("X-Service-Version", serviceConfig.serviceVersion)
            Header("X-Request-ID", requestId)
            Header("X-Environment", "\(environment)")

            // Observability headers
            if observabilityConfig.enableTracing {
              Header("X-Trace-ID", traceId)
              Header("X-Span-ID", spanId)
              Header("X-Sample-Rate", "\(observabilityConfig.sampleRate)")
            }

            if observabilityConfig.enableMetrics {
              Header("X-Metrics-Enabled", "true")
              Header("X-Request-Start", "\(Int(Date().timeIntervalSince1970 * 1000))")
            }

            if observabilityConfig.enableLogging {
              Header("X-Log-Level", environment == .production ? "info" : "debug")
              Header("X-Correlation-ID", requestId)
            }

            // Security headers
            if securityConfig.enableTLS {
              Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
            }

            if securityConfig.csrfProtection {
              Header("X-CSRF-Token", UUID().uuidString)
              Header("X-Requested-With", "XMLHttpRequest")
            }

            if securityConfig.headerSigning {
              let timestamp = "\(Int(Date().timeIntervalSince1970))"
              Header("X-Timestamp", timestamp)
              Header(
                "X-Signature",
                generateRequestSignature(
                  method: method,
                  endpoint: endpoint,
                  timestamp: timestamp,
                  body: body
                )
              )
            }

            // Performance headers
            Header("Accept-Encoding", "gzip, deflate, br")
            Header("X-Compression-Level", "high")

            // Rate limiting awareness
            Header("X-Rate-Limit-Client", "\(serviceConfig.rateLimitPerMinute)")
            Header("X-Client-Priority", "normal")

            // Additional headers
            for (key, value) in additionalHeaders {
              Header(key, value)
            }

            // Body
            if let bodyData = body {
              ContentType(.json)
              DataBody(bodyData)

              if securityConfig.requestEncryption {
                Header("X-Content-Encrypted", "true")
                Header("X-Encryption-Version", "v2")
              }
            }

            AcceptHeader(.json)
            UserAgent("ProductionClient/\(serviceConfig.serviceVersion)")
          }
        }

        private func generateRequestSignature(
          method: String,
          endpoint: String,
          timestamp: String,
          body: Data?
        ) -> String {
          // Simplified signature generation for demo
          let components = [
            method.uppercased(),
            endpoint,
            timestamp,
            body?.sha256Hash ?? "",
          ].joined(separator: "\n")

          return components.data(using: .utf8)?.sha256Hash ?? "invalid-signature"
        }
      }

      let productionBuilder = ProductionRequestBuilder(
        environment: .production,
        serviceConfig: ProductionRequestBuilder.ServiceConfiguration(
          baseURL: "https://api.enterprise.com",
          apiVersion: "v3",
          serviceVersion: "2.1.0",
          timeout: 30.0,
          retryAttempts: 3,
          rateLimitPerMinute: 1000
        ),
        securityConfig: ProductionRequestBuilder.SecurityConfiguration(
          enableTLS: true,
          certificatePinning: true,
          headerSigning: true,
          requestEncryption: false,
          csrfProtection: true
        ),
        observabilityConfig: ProductionRequestBuilder.ObservabilityConfiguration(
          enableMetrics: true,
          enableTracing: true,
          enableLogging: true,
          sampleRate: 0.1,
          errorReporting: true
        )
      )

      let productionRequest = try productionBuilder.buildEnterpriseRequest(
        method: "POST",
        endpoint: "/api/v3/transactions",
        body: try JSONSerialization.data(withJSONObject: [
          "amount": 100.50,
          "currency": "USD",
          "merchant_id": "merchant_123",
          "timestamp": Int(Date().timeIntervalSince1970),
        ]),
        additionalHeaders: [
          "X-Transaction-Type": "payment",
          "X-Merchant-Category": "retail",
          "X-Risk-Level": "low",
        ]
      )

      print("   ✅ Enterprise Production Request:")
      print("      Environment: Production")
      print("      Total Headers: \(productionRequest.headers.count)")
      print("      Has Tracing: \(productionRequest.headers["X-Trace-ID"] != nil)")
      print("      Has Security: \(productionRequest.headers["X-Signature"] != nil)")
      print("      Has CSRF Protection: \(productionRequest.headers["X-CSRF-Token"] != nil)")

      // Example 2: Error handling and validation patterns
      struct ValidatedRequestBuilder {
        enum ValidationError: LocalizedError {
          case missingRequiredHeader(String)
          case invalidURL(String)
          case bodyTooLarge(Int, max: Int)
          case unsupportedMethod(String)
          case missingAuthentication

          var errorDescription: String? {
            switch self {
            case .missingRequiredHeader(let header):
              return "Missing required header: \(header)"

            case .invalidURL(let url):
              return "Invalid URL: \(url)"

            case .bodyTooLarge(let size, let max):
              return "Body too large: \(size) bytes (max: \(max))"

            case .unsupportedMethod(let method):
              return "Unsupported HTTP method: \(method)"

            case .missingAuthentication:
              return "Authentication required but not provided"
            }
          }
        }

        struct ValidationRules {
          let requiredHeaders: [String]
          let maxBodySize: Int
          let allowedMethods: Set<String>
          let requireAuthentication: Bool
          let validateURL: Bool
        }

        static func buildValidatedRequest(
          method: String,
          url: String,
          headers: [String: String] = [:],
          body: Data? = nil,
          authToken: String? = nil,
          rules: ValidationRules
        ) throws -> HTTPRequest {
          // Validate method
          guard rules.allowedMethods.contains(method.uppercased()) else {
            throw ValidationError.unsupportedMethod(method)
          }

          // Validate URL
          if rules.validateURL {
            guard URL(string: url) != nil else {
              throw ValidationError.invalidURL(url)
            }
          }

          // Validate required headers
          for requiredHeader in rules.requiredHeaders {
            guard headers[requiredHeader] != nil else {
              throw ValidationError.missingRequiredHeader(requiredHeader)
            }
          }

          // Validate body size
          if let bodyData = body, bodyData.count > rules.maxBodySize {
            throw ValidationError.bodyTooLarge(bodyData.count, max: rules.maxBodySize)
          }

          // Validate authentication
          if rules.requireAuthentication && authToken == nil {
            throw ValidationError.missingAuthentication
          }

          // Build validated request
          return try RequestBuilder.build {
            switch method.uppercased() {
            case "GET": GET("")
            case "POST": POST("")
            case "PUT": PUT("")
            case "DELETE": DELETE("")
            case "PATCH": PATCH("")
            default: GET("")
            }

            RequestBaseURL(url)

            // Add all headers
            for (key, value) in headers {
              Header(key, value)
            }

            // Add authentication
            if let token = authToken {
              BearerAuth(token)
            }

            // Add body
            if let bodyData = body {
              DataBody(bodyData)
            }

            // Add validation metadata
            Header("X-Validated", "true")
            Header("X-Validation-Timestamp", ISO8601DateFormatter().string(from: Date()))

            AcceptHeader(.json)
            RequestTimeout(.seconds(30))
          }
        }
      }

      let validationRules = ValidatedRequestBuilder.ValidationRules(
        requiredHeaders: ["X-Client-ID", "X-API-Version"],
        maxBodySize: 1024 * 1024,  // 1MB
        allowedMethods: ["GET", "POST", "PUT", "DELETE"],
        requireAuthentication: true,
        validateURL: true
      )

      let validatedRequest = try ValidatedRequestBuilder.buildValidatedRequest(
        method: "POST",
        url: "https://api.validated.com/v1/data",
        headers: [
          "X-Client-ID": "client-123",
          "X-API-Version": "v1",
          "Content-Type": "application/json",
        ],
        body: try JSONSerialization.data(withJSONObject: ["key": "value"]),
        authToken: "validated-token-abc123",
        rules: validationRules
      )

      print("   ✅ Validated Request:")
      print("      Method: \(validatedRequest.method)")
      print("      URL Valid: \(validatedRequest.url != nil)")
      print("      Has Required Headers: true")
      print("      Has Authentication: \(validatedRequest.headers["Authorization"] != nil)")
      print(
        "      Body Size Valid: \(validatedRequest.body?.count ?? 0) <= \(validationRules.maxBodySize)"
      )
    } catch {
      print("   ❌ Production Pattern Error: \(error)")
      if let validationError = error as? ValidatedRequestBuilder.ValidationError {
        print("      Validation Details: \(validationError.localizedDescription)")
      }
    }
  }
}

// MARK: - Helper Extensions and Utilities

private extension String {
  static func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
  }
}

private extension Data {
  var sha256Hash: String {
    // Simplified hash for demo purposes
    // In production, use proper SHA-256 implementation
    let base64 = self.base64EncodedString()
    return String(base64.prefix(32))
  }
}

// MARK: - Supporting Types

/// HTTP Error types for demonstration
private enum HTTPError: LocalizedError {
  case unauthorized
  case unknown

  var errorDescription: String? {
    switch self {
    case .unauthorized: return "Unauthorized access"
    case .unknown: return "Unknown HTTP error"
    }
  }
}

/// Media type constants
private extension String {
  static let json = "application/json"
  static let formURLEncoded = "application/x-www-form-urlencoded"
}

/// Accept header convenience
private extension AcceptHeader {
  static let json = AcceptHeader("application/json")
}

/// Content type convenience
private extension ContentType {
  static let json = ContentType("application/json")
  static let formURLEncoded = ContentType("application/x-www-form-urlencoded")
}
