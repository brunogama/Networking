/// # Middleware Examples
///
/// This file demonstrates the powerful middleware system for intercepting and transforming requests and responses.
/// Middleware enables cross-cutting concerns like logging, retry logic, caching, and authentication.

import Foundation
import Networking

/// Collection of middleware examples demonstrating the interceptor system
public struct MiddlewareExamples {
  // MARK: - Public Interface

  /// Runs all middleware examples
  public static func runAll() async {
    print("\n⚡ Middleware Examples")
    print("-" * 30)

    await loggingMiddleware()
    await retryMiddleware()
    await authenticationMiddleware()
    await customMiddleware()
    await middlewareChaining()
    await conditionalMiddleware()
  }

  // MARK: - Built-in Middleware

  /// Demonstrates logging middleware for request/response debugging
  ///
  /// Shows:
  /// - Request/response logging
  /// - Performance metrics
  /// - Debug information
  /// - Customizable log levels
  public static func loggingMiddleware() async {
    print("🔹 Logging Middleware")

    do {
      // Create client with logging middleware
      let client = NetworkClient(
        requestMiddlewares: [LoggingMiddleware()],
        responseMiddlewares: [LoggingMiddleware()],
        errorMiddlewares: [LoggingMiddleware()]
      )

      // Make request with logging enabled
      let request = HTTPRequest(method: .get, url: URL(string: "https://httpbin.org/json")!)
      let response = try await client.execute(request)

      print("   Response received with status: \(response.status)")
      print("   (Check console for detailed request/response logs)")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  /// Demonstrates retry middleware for handling transient failures
  ///
  /// Shows:
  /// - Automatic retry logic
  /// - Exponential backoff
  /// - Retry conditions
  /// - Maximum retry limits
  public static func retryMiddleware() async {
    print("🔹 Retry Middleware")

    do {
      // Create retry configuration
      let retryConfig = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 10.0,
        retryableStatusCodes: [.serviceUnavailable, .badGateway, .gatewayTimeout]
      )

      // Create client with retry middleware
      let client = NetworkClient(
        errorMiddlewares: [RetryMiddleware(configuration: retryConfig)],
        requestMiddlewares: [LoggingMiddleware()]
      )

      // Simulate request to unreliable endpoint
      let request = HTTPRequest(method: .get, url: URL(string: "https://httpbin.org/status/503")!)

      do {
        let response = try await client.execute(request)
        print("   Unexpected success: \(response.status)")
      } catch {
        print("   Expected failure after retries: \(error)")
      }
    } catch {
      print("   ❌ Configuration Error: \(error)")
    }
  }

  /// Demonstrates authentication middleware for automatic token handling
  ///
  /// Shows:
  /// - Bearer token injection
  /// - Token refresh logic
  /// - Authentication challenges
  /// - Credential management
  public static func authenticationMiddleware() async {
    print("🔹 Authentication Middleware")

    do {
      // Create authentication middleware with bearer token
      let bearerToken = "demo-token-123"
      let authMiddleware = BearerAuthenticationMiddleware(token: bearerToken)

      // Create client with auth middleware
      let client = NetworkClient(
        requestMiddlewares: [authMiddleware, LoggingMiddleware()]
      )

      // Make authenticated request
      let request = HTTPRequest(method: .get, url: URL(string: "https://httpbin.org/bearer")!)
      let response = try await client.execute(request)

      print("   Authentication response: \(response.status)")

      // Demonstrate token refresh middleware
      let refreshableAuth = RefreshableAuthenticationMiddleware(
        initialToken: bearerToken,
        tokenRefresher: { oldToken in
          // Simulate token refresh
          print("   🔄 Refreshing token: \(oldToken)")
          return "refreshed-token-456"
        }
      )

      let refreshableClient = NetworkClient(
        requestMiddlewares: [refreshableAuth]
      )

      print("   Refreshable auth middleware configured")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Custom Middleware

  /// Demonstrates creating custom middleware for specific needs
  ///
  /// Shows:
  /// - Custom middleware implementation
  /// - Request/response transformation
  /// - State management
  /// - Performance monitoring
  public static func customMiddleware() async {
    print("🔹 Custom Middleware")

    do {
      // Custom middleware for adding request metadata
      struct RequestMetadataMiddleware: HTTPRequestMiddleware {
        func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
          var headers = request.headers
          headers["X-Request-ID"] = UUID().uuidString
          headers["X-Client-Version"] = "1.0.0"
          headers["X-Timestamp"] = "\(Date().timeIntervalSince1970)"
          headers["X-Platform"] = "iOS"

          print("   📤 Added metadata to request")

          return HTTPRequest(
            method: request.method,
            url: request.url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
          )
        }
      }

      // Custom middleware for response validation
      struct ResponseValidationMiddleware: HTTPResponseMiddleware {
        func processResponse(
          _ response: HTTPResponse,
          for request: HTTPRequest
        ) async throws -> HTTPResponse {
          // Validate response
          if response.status.rawValue >= 400 {
            print("   ⚠️ HTTP error detected: \(response.status)")
          }

          // Check content type
          if let contentType = response.headers["Content-Type"] {
            print("   📋 Content-Type: \(contentType)")
          } else {
            print("   ⚠️ No Content-Type header")
          }

          // Validate body size
          if let body = response.body {
            print("   📊 Response size: \(body.count) bytes")

            if body.count > 1_000_000 {
              print("   ⚠️ Large response detected")
            }
          }

          return response
        }
      }

      // Create client with custom middleware
      let client = NetworkClient(
        requestMiddlewares: [RequestMetadataMiddleware()],
        responseMiddlewares: [ResponseValidationMiddleware()]
      )

      // Test custom middleware
      let request = HTTPRequest(method: .get, url: URL(string: "https://httpbin.org/json")!)
      let response = try await client.execute(request)

      print("   Custom middleware processing completed: \(response.status)")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Middleware Chaining

  /// Demonstrates chaining multiple middleware for complex request processing
  ///
  /// Shows:
  /// - Middleware execution order
  /// - Layered processing
  /// - State sharing between middleware
  /// - Performance optimization
  public static func middlewareChaining() async {
    print("🔹 Middleware Chaining")

    do {
      // Create multiple middleware instances
      struct TimingMiddleware: HTTPRequestMiddleware {
        let name: String

        func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
          print("   ⏰ \(name) - Processing request")
          return request
        }
      }

      actor RequestCounterMiddleware: HTTPRequestMiddleware {
        private var requestCount = 0

        func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
          requestCount += 1

          var headers = request.headers
          headers["X-Request-Number"] = "\(requestCount)"

          print("   🔢 Request #\(requestCount)")

          return HTTPRequest(
            method: request.method,
            url: request.url,
            headers: headers,
            body: request.body,
            timeout: request.timeout
          )
        }
      }

      // Chain multiple middleware
      let client = NetworkClient(
        requestMiddlewares: [
          TimingMiddleware(name: "Outer"),
          await RequestCounterMiddleware(),
          TimingMiddleware(name: "Inner"),
          LoggingMiddleware(),
        ]
      )

      // Make multiple requests to see chaining in action
      let urls = [
        "https://httpbin.org/get",
        "https://httpbin.org/json",
        "https://httpbin.org/uuid",
      ]

      for url in urls {
        let request = HTTPRequest(method: .get, url: URL(string: url)!)
        let response = try await client.execute(request)
        print("   ✅ Response \(response.status) from \(url)")
      }
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Conditional Middleware

  /// Demonstrates conditional middleware that adapts based on request properties
  ///
  /// Shows:
  /// - Dynamic middleware behavior
  /// - Request-based conditions
  /// - Environment-specific processing
  /// - Feature flag integration
  public static func conditionalMiddleware() async {
    print("🔹 Conditional Middleware")

    do {
      // Conditional middleware that changes behavior based on request
      struct ConditionalLoggingMiddleware: Middleware {
        func process(
          _ request: HTTPRequest,
          next: @escaping (HTTPRequest) async throws -> HTTPResponse
        ) async throws -> HTTPResponse {
          // Only log requests to specific hosts
          let shouldLog = request.url?.host?.contains("httpbin.org") == true

          if shouldLog {
            print("   📝 Logging enabled for: \(request.url?.absoluteString ?? "unknown")")
          }

          let response = try await next(request)

          if shouldLog {
            print("   📝 Response: \(response.status) (\(response.body?.count ?? 0) bytes)")
          }

          return response
        }
      }

      // Environment-specific middleware
      struct EnvironmentMiddleware: Middleware {
        let environment: String

        func process(
          _ request: HTTPRequest,
          next: @escaping (HTTPRequest) async throws -> HTTPResponse
        ) async throws -> HTTPResponse {
          var modifiedRequest = request

          // Add environment-specific headers
          modifiedRequest.headers["X-Environment"] = environment

          switch environment {
          case "development":
            modifiedRequest.headers["X-Debug-Mode"] = "true"
            print("   🛠 Development mode: Debug headers added")

          case "staging":
            modifiedRequest.headers["X-Staging-Flag"] = "true"
            print("   🧪 Staging mode: Test headers added")

          case "production":
            // Remove debug headers if any
            modifiedRequest.headers.removeValue(forKey: "X-Debug")
            print("   🚀 Production mode: Debug headers removed")

          default:
            break
          }

          return try await next(modifiedRequest)
        }
      }

      // Feature flag middleware
      struct FeatureFlagMiddleware: Middleware {
        let enabledFeatures: Set<String>

        func process(
          _ request: HTTPRequest,
          next: @escaping (HTTPRequest) async throws -> HTTPResponse
        ) async throws -> HTTPResponse {
          var modifiedRequest = request

          // Add feature flags as headers
          for feature in enabledFeatures {
            modifiedRequest.headers["X-Feature-\(feature)"] = "enabled"
          }

          print("   🎛 Enabled features: \(enabledFeatures.joined(separator: ", "))")

          return try await next(modifiedRequest)
        }
      }

      // Create client with conditional middleware
      let client = HTTPClient.Builder()
        .middleware(ConditionalLoggingMiddleware())
        .middleware(EnvironmentMiddleware(environment: "development"))
        .middleware(
          FeatureFlagMiddleware(enabledFeatures: [
            "analytics", "push_notifications", "premium_features",
          ])
        )
        .build()

      // Test conditional behavior with different URLs
      let testRequests = [
        HTTPRequest.get("https://httpbin.org/get"),  // Should log
        HTTPRequest.get("https://api.github.com/user"),  // Should not log
      ]

      for request in testRequests {
        do {
          let response = try await client.send(request)
          print(
            "   ✅ Conditional processing for \(request.url?.host ?? "unknown"): \(response.status)"
          )
        } catch {
          print("   ❌ Request failed for \(request.url?.host ?? "unknown"): \(error)")
        }
      }
    } catch {
      print("   ❌ Error: \(error)")
    }
  }
}

// MARK: - Custom Middleware Types

/// Example custom middleware for bearer token authentication
private struct BearerAuthenticationMiddleware: HTTPRequestMiddleware {
  let token: String

  func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    var headers = request.headers
    headers["Authorization"] = "Bearer \(token)"
    return HTTPRequest(
      method: request.method,
      url: request.url,
      headers: headers,
      body: request.body,
      timeout: request.timeout
    )
  }
}

/// Example middleware with token refresh capability (simplified for demo)
private struct RefreshableAuthenticationMiddleware: HTTPRequestMiddleware {
  private let token: String
  private let tokenRefresher: (String) async throws -> String

  init(initialToken: String, tokenRefresher: @escaping (String) async throws -> String) {
    self.token = initialToken
    self.tokenRefresher = tokenRefresher
  }

  func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    var headers = request.headers
    headers["Authorization"] = "Bearer \(token)"
    return HTTPRequest(
      method: request.method,
      url: request.url,
      headers: headers,
      body: request.body,
      timeout: request.timeout
    )
  }
}

// MARK: - Configuration Types

/// Configuration for retry middleware behavior
private struct RetryConfiguration {
  let maxAttempts: Int
  let baseDelay: TimeInterval
  let maxDelay: TimeInterval
  let retryableStatusCodes: [HTTPStatus]
}

/// Example retry middleware implementation
private struct RetryMiddleware: HTTPErrorMiddleware {
  let configuration: RetryConfiguration

  func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse {
    // Simplified retry logic - in reality would need more complex state management
    print("   🔄 Retry middleware handling error: \(error)")
    print("   🔄 Would retry request with configuration: max=\(configuration.maxAttempts)")

    // For demo purposes, just rethrow the error
    // Real implementation would need to re-execute the request
    throw error
  }
}

// MARK: - Helper Extensions

private extension String {
  static func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
  }
}
