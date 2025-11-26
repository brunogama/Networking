/// # Request Building Examples
///
/// This file demonstrates the powerful RequestBuilder DSL system for creating complex HTTP requests.
/// The DSL provides a declarative, type-safe way to compose HTTP requests with advanced features.

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
}
private let UIDevice = DeviceInfo.self
#endif

/// Collection of request building examples demonstrating the DSL system
public struct RequestBuildingExamples {
  // MARK: - Public Interface

  /// Runs all request building examples
  public static func runAll() async {
    print("\n🔨 Request Building Examples")
    print("-" * 30)

    await basicDSLUsage()
    await advancedDSLPatterns()
    await conditionalRequestBuilding()
    await requestTemplates()
    await compositeRequests()
    await dynamicRequestGeneration()
  }

  // MARK: - Basic DSL Usage

  /// Demonstrates basic RequestBuilder DSL patterns
  ///
  /// Shows:
  /// - Simple DSL syntax
  /// - Component composition
  /// - Method chaining
  /// - Clean request construction
  public static func basicDSLUsage() async {
    print("🔹 Basic DSL Usage")

    do {
      let client = NetworkClient()

      // Example 1: Simple GET with headers
      let request1 = try RequestBuilder.build {
        GET("/user")
        RequestBaseURL("https://api.github.com")
        Header("Accept", "application/vnd.github.v3+json")
        Header("User-Agent", "Swift-Networking-Demo")
      }

      print("   Request 1 - Method: \(request1.method), URL: \(request1.url)")

      // Example 2: POST with JSON body
      let userData = ["name": "John Doe", "email": "john@example.com"]
      let jsonData = try JSONSerialization.data(withJSONObject: userData)

      let request2 = try RequestBuilder.build {
        POST("/post")
        RequestBaseURL("https://httpbin.org")
        Header("Content-Type", "application/json")
        DataBody(jsonData)
      }

      print("   Request 2 - Method: \(request2.method), Body Size: \(request2.body?.count ?? 0)")

      // Execute one request to show it works
      let response = try await client.execute(request1)
      print("   Response Status: \(response.status)")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  /// Demonstrates advanced DSL patterns and composition
  ///
  /// Shows:
  /// - Complex header management
  /// - Query parameter handling
  /// - Authentication integration
  /// - Request validation
  public static func advancedDSLPatterns() async {
    print("🔹 Advanced DSL Patterns")

    do {
      let client = NetworkClient()

      // Complex API request with multiple components
      let searchRequest = try RequestBuilder.build {
        GET("/search/repositories")
        RequestBaseURL("https://api.github.com")

        // Multiple query parameters
        QueryParam("q", "swift networking")
        QueryParam("sort", "stars")
        QueryParam("order", "desc")
        QueryParam("per_page", "10")

        // Multiple headers
        Header("Accept", "application/vnd.github.v3+json")
        Header("User-Agent", "Swift-Networking-Framework")
        Header("X-Custom-Client", "Arena-Playground")

        // Conditional authentication (would be dynamic in real app)
        if let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] {
          Header("Authorization", "token \(token)")
        }
      }

      print("   Search Request URL: \(searchRequest.url)")
      print("   Headers Count: \(searchRequest.headers.count)")

      // Complex POST request with form data
      let formData = "username=testuser&password=testpass&remember_me=true"
      let formRequest = try RequestBuilder.build {
        POST("/post")
        RequestBaseURL("https://httpbin.org")
        Header("Content-Type", "application/x-www-form-urlencoded")
        DataBody(formData.data(using: .utf8)!)
        Header("Content-Length", "\(formData.utf8.count)")
      }

      print("   Form Request - Content-Type: \(formRequest.headers["Content-Type"] ?? "None")")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Conditional Building

  /// Demonstrates conditional request building based on runtime conditions
  ///
  /// Shows:
  /// - Dynamic component inclusion
  /// - Environment-based configuration
  /// - Feature flags integration
  /// - A/B testing support
  public static func conditionalRequestBuilding() async {
    print("🔹 Conditional Request Building")

    do {
      let client = NetworkClient()

      // Simulate different user states
      struct UserContext {
        let isAuthenticated: Bool
        let isPremium: Bool
        let apiVersion: String
        let debugMode: Bool
      }

      let context = UserContext(
        isAuthenticated: true,
        isPremium: false,
        apiVersion: "v2",
        debugMode: true
      )

      let conditionalRequest = try RequestBuilder.build {
        GET("/\(context.apiVersion)/data")
        RequestBaseURL("https://api.example.com")

        // Conditional authentication
        if context.isAuthenticated {
          Header("Authorization", "Bearer fake-token-123")
        }

        // Premium features
        if context.isPremium {
          QueryParam("include_premium", "true")
          Header("X-Premium-User", "true")
        }

        // Debug information
        if context.debugMode {
          Header("X-Debug-Mode", "true")
          QueryParam("debug", "1")
        }

        // Always include common headers
        Header("Accept", "application/json")
        Header("User-Agent", "MyApp/1.0")
      }

      print("   Conditional Request URL: \(conditionalRequest.url)")
      print("   Has Auth Header: \(conditionalRequest.headers["Authorization"] != nil)")
      print(
        "   Has Premium Params: \(conditionalRequest.url?.absoluteString.contains("include_premium") ?? false)"
      )
      print("   Debug Mode: \(conditionalRequest.headers["X-Debug-Mode"] != nil)")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Request Templates

  /// Demonstrates reusable request templates for common patterns
  ///
  /// Shows:
  /// - Template creation
  /// - Parameter substitution
  /// - Common configuration reuse
  /// - API client patterns
  public static func requestTemplates() async {
    print("🔹 Request Templates")

    do {
      // Template for GitHub API requests
      func githubAPIRequest(endpoint: String) throws -> HTTPRequest {
        try RequestBuilder.build {
          GET(endpoint)
          try RequestBaseURL("https://api.github.com")
          Header("Accept", "application/vnd.github.v3+json")
          Header("User-Agent", "Swift-Networking-Framework")

          // Add auth if available
          if let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] {
            Header("Authorization", "token \(token)")
          }
        }
      }

      // Template for JSON POST requests
      func jsonPostRequest(url: String, data: Data) throws -> HTTPRequest {
        try RequestBuilder.build {
          POST("")
          try RequestBaseURL(url)
          Header("Content-Type", "application/json")
          Header("Accept", "application/json")
          DataBody(data)
        }
      }

      // Use templates
      let userRequest = try githubAPIRequest(endpoint: "/user")
      let reposRequest = try githubAPIRequest(endpoint: "/user/repos")

      print("   User Request: \(userRequest.url)")
      print("   Repos Request: \(reposRequest.url)")

      // JSON POST template usage
      let postData = try JSONSerialization.data(withJSONObject: ["test": "data"])
      let postRequest = try jsonPostRequest(url: "https://httpbin.org/post", data: postData)

      print("   POST Request Content-Type: \(postRequest.headers["Content-Type"] ?? "None")")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Composite Requests

  /// Demonstrates building complex composite requests
  ///
  /// Shows:
  /// - Multiple data sources
  /// - Complex header management
  /// - Multi-part content
  /// - Advanced composition patterns
  public static func compositeRequests() async {
    print("🔹 Composite Requests")

    do {
      // Simulate a complex API request with multiple concerns
      struct APIRequestConfig {
        let baseURL: String
        let version: String
        let clientId: String
        let features: [String]
        let locale: String
      }

      let config = APIRequestConfig(
        baseURL: "https://api.example.com",
        version: "v3",
        clientId: "mobile-app-123",
        features: ["push_notifications", "analytics", "premium_content"],
        locale: "en_US"
      )

      let compositeRequest = try RequestBuilder.build {
        POST("/\(config.version)/session/initialize")
        try RequestBaseURL(config.baseURL)

        // Client identification
        Header("X-Client-ID", config.clientId)
        Header("X-Client-Version", "1.2.3")
        Header("X-Platform", "iOS")

        // Localization
        Header("Accept-Language", config.locale)
        Header("X-Timezone", TimeZone.current.identifier)

        // Feature flags
        for feature in config.features {
          Header("X-Feature-\(feature.replacingOccurrences(of: "_", with: "-"))", "enabled")
        }

        // Request metadata
        Header("X-Request-ID", UUID().uuidString)
        Header("X-Timestamp", "\(Int(Date().timeIntervalSince1970))")

        // Standard headers
        Header("Content-Type", "application/json")
        Header("Accept", "application/json")

        // Request body
        let bodyData: [String: Any] = [
          "device_id": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
          "app_version": "1.2.3",
          "features": config.features,
          "locale": config.locale,
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: bodyData)
        DataBody(jsonData)
      }

      print("   Composite Request URL: \(compositeRequest.url)")
      print("   Total Headers: \(compositeRequest.headers.count)")
      print(
        "   Feature Headers: \(compositeRequest.headers.keys.filter { $0.hasPrefix("X-Feature-") }.count)"
      )
      print("   Body Size: \(compositeRequest.body?.count ?? 0) bytes")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Dynamic Generation

  /// Demonstrates dynamic request generation based on data
  ///
  /// Shows:
  /// - Data-driven request building
  /// - Loop-based component generation
  /// - Configuration-based requests
  /// - Programmatic composition
  public static func dynamicRequestGeneration() async {
    print("🔹 Dynamic Request Generation")

    do {
      // Simulate dynamic search request based on user criteria
      struct SearchCriteria {
        let query: String
        let filters: [String: String]
        let sortBy: String?
        let includeFacets: Bool
        let maxResults: Int
      }

      let criteria = SearchCriteria(
        query: "swift networking framework",
        filters: [
          "language": "swift",
          "license": "mit",
          "created": "2020-01-01..*",
        ],
        sortBy: "stars",
        includeFacets: true,
        maxResults: 25
      )

      let dynamicRequest = try RequestBuilder.build {
        GET("/search/repositories")
        try RequestBaseURL("https://api.github.com")

        // Base query
        QueryParam("q", criteria.query)

        // Dynamic filters
        for (key, value) in criteria.filters {
          QueryParam("q", criteria.query + " \(key):\(value)")
        }

        // Optional sorting
        if let sortBy = criteria.sortBy {
          QueryParam("sort", sortBy)
          QueryParam("order", "desc")
        }

        // Results configuration
        QueryParam("per_page", "\(criteria.maxResults)")

        // Optional facets
        if criteria.includeFacets {
          Header("X-Include-Facets", "true")
        }

        // Standard headers
        Header("Accept", "application/vnd.github.v3+json")
        Header("User-Agent", "Dynamic-Search-Client")
      }

      print("   Dynamic Request URL: \(dynamicRequest.url)")
      print(
        "   Query Parameters: \(dynamicRequest.url?.query?.components(separatedBy: "&").count ?? 0)"
      )

      // Generate multiple requests from array of criteria
      let multipleCriteria = [
        ("swift", ["language": "swift"]),
        ("python", ["language": "python"]),
        ("javascript", ["language": "javascript"]),
      ]

      let multipleRequests = try multipleCriteria.map { query, filters in
        try RequestBuilder.build {
          GET("/search/repositories")
          try RequestBaseURL("https://api.github.com")
          QueryParam("q", query)

          for (key, value) in filters {
            QueryParam(key, value)
          }

          Header("Accept", "application/vnd.github.v3+json")
        }
      }

      print("   Generated \(multipleRequests.count) requests from data")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }
}

// MARK: - Helper Extensions

private extension String {
  static func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
  }
}
