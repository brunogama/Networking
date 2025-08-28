/// # HTTP Methods Showcase
///
/// This file provides a comprehensive demonstration of all HTTP methods supported by the Networking framework.
/// Each method is showcased with real-world examples showing proper usage patterns, headers, and response handling.
///
/// ## Featured HTTP Methods
///
/// - **GET**: Data retrieval and querying
/// - **POST**: Resource creation and data submission
/// - **PUT**: Complete resource replacement
/// - **PATCH**: Partial resource updates
/// - **DELETE**: Resource removal
/// - **HEAD**: Metadata retrieval without body
/// - **OPTIONS**: Server capability discovery
/// - **CONNECT**: Tunnel establishment (proxy usage)
/// - **TRACE**: Request path diagnostic
///
/// ## Usage Patterns
///
/// Each method demonstrates:
/// - Framework RequestBuilder DSL syntax
/// - Appropriate headers and content types
/// - Real-world API interactions
/// - Proper error handling
/// - Swift 6 concurrency patterns

import Foundation
import Networking

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

/// Comprehensive showcase of all HTTP methods supported by the networking framework
///
/// This struct demonstrates the complete range of HTTP methods available in the framework,
/// providing educational examples and real-world usage patterns for each method.
public struct HTTPMethodsShowcase {

  // MARK: - Public Interface

  /// Runs all HTTP method examples in sequence
  ///
  /// This method executes comprehensive demonstrations of all 9 HTTP methods,
  /// showing practical usage patterns and proper error handling for each.
  ///
  /// - Note: Uses httpbin.org for safe testing of HTTP operations
  public static func runAll() async {
    print("\n🌐 HTTP Methods Showcase")
    print("=" * 50)

    await getRequestExamples()
    await postRequestExamples()
    await putRequestExamples()
    await patchRequestExamples()
    await deleteRequestExamples()
    await headRequestExamples()
    await optionsRequestExamples()
    await connectRequestExamples()
    await traceRequestExamples()

    print("\n✅ All HTTP method examples completed!")
  }

  // MARK: - GET Method Examples

  /// Demonstrates GET method usage patterns
  ///
  /// GET is used for retrieving data without side effects. This method shows:
  /// - Simple data retrieval
  /// - Query parameter usage
  /// - RESTful resource access
  /// - Conditional requests with headers
  /// - Multiple response format handling
  public static func getRequestExamples() async {
    print("\n🔹 GET Method Examples")
    print("-" * 30)

    do {
      let client = NetworkClient()

      // Example 1: Simple GET request
      print("📖 Simple data retrieval")
      let request1 = try RequestBuilder.build {
        GET("/json")
        try RequestBaseURL("https://httpbin.org")
        Header("Accept", "application/json")
        Header("User-Agent", "Swift-Networking-HTTPMethods/1.0")
      }

      let response1 = try await client.execute(request1)
      print("   Status: \(response1.status) - Simple JSON retrieval")

      // Example 2: GET with query parameters (search/filter pattern)
      print("🔍 Search with query parameters")
      let request2 = try RequestBuilder.build {
        GET("/get")
        try RequestBaseURL("https://httpbin.org")
        QueryParam("search", "swift networking")
        QueryParam("category", "ios-development")
        QueryParam("limit", "25")
        QueryParam("offset", "0")
        Header("Accept", "application/json")
      }

      let response2 = try await client.execute(request2)
      print("   Status: \(response2.status) - Search with parameters")
      print("   Query URL: \(request2.url)")

      // Example 3: Conditional GET with cache headers
      print("⚡ Conditional GET request")
      let request3 = try RequestBuilder.build {
        GET("/etag/example-etag")
        try RequestBaseURL("https://httpbin.org")
        Header("If-None-Match", "example-etag")
        Header("If-Modified-Since", "Wed, 21 Oct 2023 07:28:00 GMT")
        Header("Cache-Control", "max-age=3600")
      }

      let response3 = try await client.execute(request3)
      print("   Status: \(response3.status) - Conditional request")

      // Example 4: API resource access pattern
      print("🎯 RESTful resource access")
      let request4 = try RequestBuilder.build {
        GET("/uuid")
        try RequestBaseURL("https://httpbin.org")
        Header("Accept", "application/json")
        Header("X-Custom-Client", "iOS-App")
        Header("X-Request-ID", UUID().uuidString)
      }

      let response4 = try await client.execute(request4)
      print("   Status: \(response4.status) - Resource access")

    } catch {
      print("   ❌ GET Error: \(error)")
    }
  }

  // MARK: - POST Method Examples

  /// Demonstrates POST method usage patterns
  ///
  /// POST is used for creating resources and submitting data. This method shows:
  /// - JSON data submission
  /// - Form data posting
  /// - File upload simulation
  /// - Authentication workflows
  /// - Resource creation patterns
  public static func postRequestExamples() async {
    print("\n🔹 POST Method Examples")
    print("-" * 30)

    do {
      let client = NetworkClient()

      // Example 1: JSON data submission
      print("📝 JSON data submission")
      let userData =
        [
          "name": "John Doe",
          "email": "john.doe@example.com",
          "role": "developer",
          "preferences": [
            "notifications": true,
            "theme": "dark",
          ],
        ] as [String: Any]

      let jsonData = try JSONSerialization.data(withJSONObject: userData)
      let request1 = try RequestBuilder.build {
        POST("/post")
        try RequestBaseURL("https://httpbin.org")
        Header("Content-Type", "application/json")
        Header("Accept", "application/json")
        DataBody(jsonData)
      }

      let response1 = try await client.execute(request1)
      print("   Status: \(response1.status) - User data created")

      // Example 2: Form data submission
      print("📋 Form data submission")
      let formData = "username=johndoe&password=secure123&remember_me=true&newsletter=on"
      let request2 = try RequestBuilder.build {
        POST("/post")
        try RequestBaseURL("https://httpbin.org")
        Header("Content-Type", "application/x-www-form-urlencoded")
        Header("Content-Length", "\(formData.utf8.count)")
        DataBody(formData.data(using: .utf8)!)
      }

      let response2 = try await client.execute(request2)
      print("   Status: \(response2.status) - Form submitted")

      // Example 3: Authentication request
      print("🔐 Authentication request")
      let authData: [String: String] = [
        "grant_type": "password",
        "username": "demo@example.com",
        "password": "demo123",
        "scope": "read write",
      ]
      let authJSON = try JSONSerialization.data(withJSONObject: authData)

      let request3 = try RequestBuilder.build {
        POST("/post")  // Simulating /oauth/token
        try RequestBaseURL("https://httpbin.org")
        Header("Content-Type", "application/json")
        Header("Accept", "application/json")
        Header("Authorization", "Basic Y2xpZW50OnNlY3JldA==")  // client:secret
        DataBody(authJSON)
      }

      let response3 = try await client.execute(request3)
      print("   Status: \(response3.status) - Authentication attempt")

      // Example 4: Multipart simulation
      print("📎 File upload simulation")
      let boundary = "----formdata-swift-networking"
      let multipartData = """
        ------formdata-swift-networking\r
        Content-Disposition: form-data; name="file"; filename="document.txt"\r
        Content-Type: text/plain\r
        \r
        This is a sample file upload using multipart/form-data.\r
        It demonstrates file upload capabilities.\r
        ------formdata-swift-networking\r
        Content-Disposition: form-data; name="description"\r
        \r
        Important document for processing\r
        ------formdata-swift-networking--\r
        """.data(using: .utf8)!

      let request4 = try RequestBuilder.build {
        POST("/post")
        try RequestBaseURL("https://httpbin.org")
        Header("Content-Type", "multipart/form-data; boundary=\(boundary)")
        DataBody(multipartData)
      }

      let response4 = try await client.execute(request4)
      print("   Status: \(response4.status) - File upload")

    } catch {
      print("   ❌ POST Error: \(error)")
    }
  }

  // MARK: - PUT Method Examples

  /// Demonstrates PUT method usage patterns
  ///
  /// PUT is used for complete resource replacement. This method shows:
  /// - Full resource updates
  /// - Idempotent operations
  /// - Resource creation via PUT
  /// - Configuration updates
  /// - State replacement
  public static func putRequestExamples() async {
    print("\n🔹 PUT Method Examples")
    print("-" * 30)

    do {
      let client = NetworkClient()

      // Example 1: Complete resource replacement
      print("🔄 Complete resource update")
      let userProfile =
        [
          "id": "12345",
          "name": "Jane Smith",
          "email": "jane.smith@example.com",
          "role": "senior_developer",
          "department": "engineering",
          "status": "active",
          "preferences": [
            "notifications": false,
            "theme": "light",
            "language": "en",
          ],
          "last_updated": ISO8601DateFormatter().string(from: Date()),
        ] as [String: Any]

      let profileData = try JSONSerialization.data(withJSONObject: userProfile)
      let request1 = try RequestBuilder.build {
        PUT("/put")  // Simulating /users/12345
        try RequestBaseURL("https://httpbin.org")
        Header("Content-Type", "application/json")
        Header("Accept", "application/json")
        Header("If-Match", "\"user-version-42\"")  // Optimistic locking
        DataBody(profileData)
      }

      let response1 = try await client.execute(request1)
      print("   Status: \(response1.status) - Profile replaced")

      // Example 2: Configuration update
      print("⚙️ Configuration replacement")
      let appConfig =
        [
          "api_version": "v2",
          "features": [
            "dark_mode": true,
            "push_notifications": true,
            "analytics": false,
            "beta_features": true,
          ],
          "limits": [
            "requests_per_hour": 1000,
            "file_upload_mb": 50,
          ],
          "maintenance_mode": false,
        ] as [String: Any]

      let configData = try JSONSerialization.data(withJSONObject: appConfig)
      let request2 = try RequestBuilder.build {
        PUT("/put")  // Simulating /config
        try RequestBaseURL("https://httpbin.org")
        Header("Content-Type", "application/json")
        Header("X-Config-Version", "1.4.2")
        DataBody(configData)
      }

      let response2 = try await client.execute(request2)
      print("   Status: \(response2.status) - Configuration updated")

      // Example 3: Idempotent creation
      print("🆕 Resource creation via PUT")
      let newResource =
        [
          "id": "resource-789",
          "type": "document",
          "title": "Important Document",
          "content": "This document was created via PUT request.",
          "tags": ["important", "urgent"],
          "created_by": "system",
          "version": 1,
        ] as [String: Any]

      let resourceData = try JSONSerialization.data(withJSONObject: newResource)
      let request3 = try RequestBuilder.build {
        PUT("/put")  // Simulating /documents/resource-789
        try RequestBaseURL("https://httpbin.org")
        Header("Content-Type", "application/json")
        Header("X-Idempotency-Key", UUID().uuidString)
        DataBody(resourceData)
      }

      let response3 = try await client.execute(request3)
      print("   Status: \(response3.status) - Resource created")

    } catch {
      print("   ❌ PUT Error: \(error)")
    }
  }

  // MARK: - PATCH Method Examples

  /// Demonstrates PATCH method usage patterns
  ///
  /// PATCH is used for partial resource updates. This method shows:
  /// - Partial data updates
  /// - JSON Patch operations
  /// - Incremental modifications
  /// - Field-specific updates
  /// - Atomic partial changes
  public static func patchRequestExamples() async {
    print("\n🔹 PATCH Method Examples")
    print("-" * 30)

    do {
      let client = NetworkClient()

      // Example 1: Simple partial update
      print("🔧 Partial resource update")
      let partialUpdate =
        [
          "status": "inactive",
          "last_login": ISO8601DateFormatter().string(from: Date()),
          "login_count": 42,
        ] as [String: Any]

      let updateData = try JSONSerialization.data(withJSONObject: partialUpdate)

      // Since PATCH component might not exist, we'll use a generic method approach
      let request1 = HTTPRequest(
        method: .patch,
        url: URL(string: "https://httpbin.org/patch")!,
        headers: [
          "Content-Type": "application/json",
          "Accept": "application/json",
          "If-Match": "\"version-123\"",
        ],
        body: updateData
      )

      let response1 = try await client.execute(request1)
      print("   Status: \(response1.status) - Partial update applied")

      // Example 2: JSON Patch format
      print("📋 JSON Patch operations")
      let jsonPatchOps: [[String: String]] = [
        [
          "op": "replace",
          "path": "/email",
          "value": "newemail@example.com",
        ],
        [
          "op": "add",
          "path": "/tags/-",
          "value": "premium",
        ],
        [
          "op": "remove",
          "path": "/temporary_flag",
        ],
      ]

      let patchData = try JSONSerialization.data(withJSONObject: jsonPatchOps)
      let request2 = HTTPRequest(
        method: .patch,
        url: URL(string: "https://httpbin.org/patch")!,
        headers: [
          "Content-Type": "application/json-patch+json",
          "Accept": "application/json",
        ],
        body: patchData
      )

      let response2 = try await client.execute(request2)
      print("   Status: \(response2.status) - JSON Patch applied")

      // Example 3: Merge patch
      print("🔗 Merge patch update")
      let mergeUpdate =
        [
          "preferences": [
            "theme": "auto",  // Update existing
            "new_feature": true,  // Add new
          ],
          "metadata": [
            "updated_at": ISO8601DateFormatter().string(from: Date()),
            "updated_by": "mobile-app",
          ],
        ] as [String: Any]

      let mergeData = try JSONSerialization.data(withJSONObject: mergeUpdate)
      let request3 = HTTPRequest(
        method: .patch,
        url: URL(string: "https://httpbin.org/patch")!,
        headers: [
          "Content-Type": "application/merge-patch+json",
          "Accept": "application/json",
        ],
        body: mergeData
      )

      let response3 = try await client.execute(request3)
      print("   Status: \(response3.status) - Merge patch applied")

    } catch {
      print("   ❌ PATCH Error: \(error)")
    }
  }

  // MARK: - DELETE Method Examples

  /// Demonstrates DELETE method usage patterns
  ///
  /// DELETE is used for resource removal. This method shows:
  /// - Resource deletion
  /// - Bulk deletion
  /// - Conditional deletion
  /// - Soft delete patterns
  /// - Cleanup operations
  public static func deleteRequestExamples() async {
    print("\n🔹 DELETE Method Examples")
    print("-" * 30)

    do {
      let client = NetworkClient()

      // Example 1: Simple resource deletion
      print("🗑️ Simple resource deletion")
      let request1 = try RequestBuilder.build {
        DELETE("/delete")  // Simulating /users/123
        try RequestBaseURL("https://httpbin.org")
        Header("Accept", "application/json")
        Header("Authorization", "Bearer demo-token-123")
      }

      let response1 = try await client.execute(request1)
      print("   Status: \(response1.status) - Resource deleted")

      // Example 2: Conditional deletion with safety check
      print("🛡️ Conditional deletion")
      let request2 = HTTPRequest(
        method: .delete,
        url: URL(string: "https://httpbin.org/delete")!,
        headers: [
          "If-Match": "\"resource-version-456\"",  // Ensure version matches
          "X-Confirm-Delete": "true",  // Additional safety
          "X-Deletion-Reason": "User requested account closure",
        ]
      )

      let response2 = try await client.execute(request2)
      print("   Status: \(response2.status) - Conditional deletion")

      // Example 3: Bulk deletion request
      print("📦 Bulk deletion")
      let bulkDeleteRequest: [String: Any] = [
        "items": ["item-1", "item-2", "item-3"],
        "confirm": true,
        "reason": "Cleanup outdated data",
      ]

      let bulkData = try JSONSerialization.data(withJSONObject: bulkDeleteRequest)
      let request3 = HTTPRequest(
        method: .delete,
        url: URL(string: "https://httpbin.org/delete")!,
        headers: [
          "Content-Type": "application/json",
          "X-Bulk-Operation": "true",
        ],
        body: bulkData
      )

      let response3 = try await client.execute(request3)
      print("   Status: \(response3.status) - Bulk deletion")

      // Example 4: Soft delete pattern
      print("♻️ Soft delete pattern")
      let softDeleteData: [String: Any] = [
        "deleted": true,
        "deleted_at": ISO8601DateFormatter().string(from: Date()),
        "deleted_by": "user-123",
        "reason": "No longer needed",
      ]

      let softData = try JSONSerialization.data(withJSONObject: softDeleteData)
      let request4 = HTTPRequest(
        method: .delete,
        url: URL(string: "https://httpbin.org/delete")!,
        headers: [
          "Content-Type": "application/json",
          "X-Soft-Delete": "true",
        ],
        body: softData
      )

      let response4 = try await client.execute(request4)
      print("   Status: \(response4.status) - Soft deletion")

    } catch {
      print("   ❌ DELETE Error: \(error)")
    }
  }

  // MARK: - HEAD Method Examples

  /// Demonstrates HEAD method usage patterns
  ///
  /// HEAD returns only headers without body content. This method shows:
  /// - Resource existence checks
  /// - Content metadata retrieval
  /// - Cache validation
  /// - Resource monitoring
  /// - Bandwidth optimization
  public static func headRequestExamples() async {
    print("\n🔹 HEAD Method Examples")
    print("-" * 30)

    do {
      let client = NetworkClient()

      // Example 1: Resource existence check
      print("✅ Resource existence check")
      let request1 = HTTPRequest(
        method: .head,
        url: URL(string: "https://httpbin.org/json")!,
        headers: [
          "User-Agent": "Swift-Networking-HEAD-Check"
        ]
      )

      let response1 = try await client.execute(request1)
      print(
        "   Status: \(response1.status) - Resource exists: \(response1.status.isSuccess)"
      )
      print("   Content-Length: \(response1.headers["Content-Length"] ?? "Unknown")")
      print("   Content-Type: \(response1.headers["Content-Type"] ?? "Unknown")")
      print("   Body is empty: \(response1.body?.isEmpty ?? true)")

      // Example 2: Cache validation
      print("🔄 Cache validation")
      let request2 = HTTPRequest(
        method: .head,
        url: URL(string: "https://httpbin.org/etag/test-etag")!,
        headers: [
          "If-None-Match": "test-etag",
          "Cache-Control": "no-cache",
        ]
      )

      let response2 = try await client.execute(request2)
      print("   Status: \(response2.status) - Cache check")
      print("   ETag: \(response2.headers["ETag"] ?? "None")")
      print("   Last-Modified: \(response2.headers["Last-Modified"] ?? "None")")

      // Example 3: File metadata check
      print("📄 File metadata check")
      let request3 = HTTPRequest(
        method: .head,
        url: URL(string: "https://httpbin.org/bytes/1024")!
      )

      let response3 = try await client.execute(request3)
      print("   Status: \(response3.status) - File info retrieved")
      print("   Content-Length: \(response3.headers["Content-Length"] ?? "Unknown") bytes")
      print("   Accept-Ranges: \(response3.headers["Accept-Ranges"] ?? "None")")

      // Example 4: API endpoint availability
      print("🌐 API endpoint health check")
      let request4 = HTTPRequest(
        method: .head,
        url: URL(string: "https://httpbin.org/status/200")!,
        headers: [
          "X-Health-Check": "true"
        ]
      )

      let response4 = try await client.execute(request4)
      print("   Status: \(response4.status) - API health")
      print("   Server: \(response4.headers["Server"] ?? "Unknown")")

    } catch {
      print("   ❌ HEAD Error: \(error)")
    }
  }

  // MARK: - OPTIONS Method Examples

  /// Demonstrates OPTIONS method usage patterns
  ///
  /// OPTIONS is used to discover server capabilities. This method shows:
  /// - CORS preflight requests
  /// - Server capability discovery
  /// - Allowed methods checking
  /// - API feature detection
  /// - Cross-origin request preparation
  public static func optionsRequestExamples() async {
    print("\n🔹 OPTIONS Method Examples")
    print("-" * 30)

    do {
      let client = NetworkClient()

      // Example 1: CORS preflight request
      print("🌍 CORS preflight request")
      let request1 = HTTPRequest(
        method: .options,
        url: URL(string: "https://httpbin.org/json")!,
        headers: [
          "Origin": "https://example.com",
          "Access-Control-Request-Method": "POST",
          "Access-Control-Request-Headers": "Content-Type, Authorization",
        ]
      )

      let response1 = try await client.execute(request1)
      print("   Status: \(response1.status) - CORS preflight")
      print("   Allowed Methods: \(response1.headers["Allow"] ?? "Not specified")")
      print("   CORS Headers: \(response1.headers["Access-Control-Allow-Headers"] ?? "None")")
      print("   Max Age: \(response1.headers["Access-Control-Max-Age"] ?? "None")")

      // Example 2: Server capability discovery
      print("🔍 Server capabilities")
      let request2 = HTTPRequest(
        method: .options,
        url: URL(string: "https://httpbin.org")!,  // Root endpoint
        headers: [
          "User-Agent": "Swift-Networking-Capabilities-Check"
        ]
      )

      let response2 = try await client.execute(request2)
      print("   Status: \(response2.status) - Capabilities discovered")
      print("   Allowed: \(response2.headers["Allow"] ?? "Not specified")")
      print("   Server: \(response2.headers["Server"] ?? "Unknown")")

      // Example 3: Specific resource options
      print("📋 Resource-specific options")
      let request3 = HTTPRequest(
        method: .options,
        url: URL(string: "https://httpbin.org/anything")!,
        headers: [
          "X-Requested-With": "XMLHttpRequest"
        ]
      )

      let response3 = try await client.execute(request3)
      print("   Status: \(response3.status) - Resource options")
      if let contentLength = response3.headers["Content-Length"] {
        print("   Response has body: \(contentLength != "0")")
      }

      // Example 4: API version negotiation
      print("🔢 API version options")
      let request4 = HTTPRequest(
        method: .options,
        url: URL(string: "https://httpbin.org/anything")!,
        headers: [
          "Accept": "application/json",
          "API-Version": "v2",
        ]
      )

      let response4 = try await client.execute(request4)
      print("   Status: \(response4.status) - Version negotiation")

    } catch {
      print("   ❌ OPTIONS Error: \(error)")
    }
  }

  // MARK: - CONNECT Method Examples

  /// Demonstrates CONNECT method usage patterns
  ///
  /// CONNECT is used for establishing tunnels, primarily for proxy connections.
  /// This method shows:
  /// - Proxy tunnel establishment
  /// - HTTPS through proxy
  /// - Tunnel connection patterns
  /// - Proxy authentication
  ///
  /// - Note: Most test servers don't support CONNECT, so these are demonstration examples
  public static func connectRequestExamples() async {
    print("\n🔹 CONNECT Method Examples")
    print("-" * 30)

    // CONNECT is typically not supported by httpbin.org or most test services
    // These are educational examples showing the structure

    print("🔌 CONNECT method demonstration (educational)")
    print("   Note: CONNECT is used for proxy tunneling and is rarely testable")
    print("   against public APIs. Examples show proper request structure.")

    do {
      // Example 1: Basic tunnel establishment
      print("🌐 Basic proxy tunnel")
      let request1 = HTTPRequest(
        method: .connect,
        url: URL(string: "https://httpbin.org:443")!,  // This will likely fail
        headers: [
          "Host": "httpbin.org:443",
          "User-Agent": "Swift-Networking-Tunnel",
        ]
      )

      print("   Request URL: \(request1.url.absoluteString)")
      print("   Method: \(request1.method.rawValue)")
      print("   Host Header: \(request1.headers["Host"] ?? "None")")
      print("   Note: Would establish tunnel to httpbin.org:443")

      // Example 2: Authenticated proxy
      print("🔐 Authenticated proxy tunnel")
      let credentials = "proxyuser:proxypass"
      let encodedCredentials = Data(credentials.utf8).base64EncodedString()

      let request2 = HTTPRequest(
        method: .connect,
        url: URL(string: "https://httpbin.org:443")!,
        headers: [
          "Host": "httpbin.org:443",
          "Proxy-Authorization": "Basic \(encodedCredentials)",
          "User-Agent": "Swift-Networking-AuthTunnel",
        ]
      )

      print("   Proxy-Auth: Present (Basic)")
      print("   Note: Would authenticate with proxy server")

      // Example 3: CONNECT for WebSocket upgrade
      print("🔄 WebSocket tunnel preparation")
      let request3 = HTTPRequest(
        method: .connect,
        url: URL(string: "wss://echo.websocket.org:443")!,
        headers: [
          "Host": "echo.websocket.org:443",
          "Upgrade": "websocket",
          "Connection": "Upgrade",
        ]
      )

      print("   WebSocket tunnel structure prepared")
      print("   Note: CONNECT typically precedes WebSocket upgrade")

      print("   ⚠️  CONNECT requests typically fail against test servers")
      print("   as they don't support proxy functionality.")

    } catch {
      print("   ❌ CONNECT Error: \(error)")
    }
  }

  // MARK: - TRACE Method Examples

  /// Demonstrates TRACE method usage patterns
  ///
  /// TRACE is used for diagnostic purposes to see the request path.
  /// This method shows:
  /// - Request path diagnostics
  /// - Proxy behavior analysis
  /// - Request modification detection
  /// - Network debugging
  ///
  /// - Note: Many servers disable TRACE for security reasons
  public static func traceRequestExamples() async {
    print("\n🔹 TRACE Method Examples")
    print("-" * 30)

    do {
      let client = NetworkClient()

      // Example 1: Basic trace request
      print("🔍 Request path trace")
      let request1 = HTTPRequest(
        method: .trace,
        url: URL(string: "https://httpbin.org/anything")!,  // Using /anything as it's more permissive
        headers: [
          "User-Agent": "Swift-Networking-Trace",
          "X-Custom-Header": "trace-test-header",
          "Accept": "*/*",
        ]
      )

      let response1 = try await client.execute(request1)
      print("   Status: \(response1.status) - Trace response")

      if response1.status.isSuccess {
        print("   Server supports TRACE method")
        if let body = response1.body, let bodyString = String(data: body, encoding: .utf8) {
          print("   Response shows request path: \(bodyString.count) characters")
        }
      } else {
        print("   Server blocked TRACE (common security practice)")
      }

      // Example 2: TRACE with proxy headers
      print("🔄 Proxy behavior trace")
      let request2 = HTTPRequest(
        method: .trace,
        url: URL(string: "https://httpbin.org/anything")!,
        headers: [
          "Via": "1.1 proxy.example.com",  // Simulate proxy
          "X-Forwarded-For": "192.168.1.100",
          "X-Real-IP": "203.0.113.42",
          "Max-Forwards": "10",  // Limit trace hops
        ]
      )

      let response2 = try await client.execute(request2)
      print("   Status: \(response2.status) - Proxy trace")
      print("   Max-Forwards used: \(request2.headers["Max-Forwards"] ?? "None")")

      // Example 3: Security analysis trace
      print("🛡️ Security analysis")
      let request3 = HTTPRequest(
        method: .trace,
        url: URL(string: "https://httpbin.org/anything")!,
        headers: [
          "X-Trace-Purpose": "Security-Analysis",
          "Authorization": "Bearer test-token",  // See if this gets echoed back
          "Cookie": "session=test123",  // See if sensitive data is exposed
          "User-Agent": "Security-Scanner/1.0",
        ]
      )

      let response3 = try await client.execute(request3)
      print("   Status: \(response3.status) - Security trace")

      if response3.status.isSuccess {
        print("   ⚠️  Server allows TRACE - potential security concern")
      } else {
        print("   ✅ Server properly blocks TRACE method")
      }

      // Example 4: Diagnostic information
      print("🔧 Network diagnostic")
      let request4 = HTTPRequest(
        method: .trace,
        url: URL(string: "https://httpbin.org/anything")!,
        headers: [
          "X-Request-ID": UUID().uuidString,
          "X-Client-IP": "198.51.100.42",
          "X-Timestamp": "\(Int(Date().timeIntervalSince1970))",
          "Diagnostic-Mode": "enabled",
        ]
      )

      let response4 = try await client.execute(request4)
      print("   Status: \(response4.status) - Diagnostic complete")
      print("   Request ID: \(request4.headers["X-Request-ID"] ?? "None")")

      print("\n   📝 TRACE Method Notes:")
      print("   - Often disabled for security reasons")
      print("   - Can expose sensitive headers in response")
      print("   - Useful for debugging proxy chains")
      print("   - Should be carefully controlled in production")

    } catch {
      print("   ❌ TRACE Error: \(error)")
    }
  }
}

// MARK: - Helper Extensions

private extension String {
  static func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
  }
}

// HTTPStatus already has isSuccess property, no extension needed
