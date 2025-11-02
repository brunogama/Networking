/// # Basic Networking Examples
///
/// This file demonstrates the most fundamental networking operations using the Networking framework.
/// These examples show how to perform common HTTP operations with clean, modern Swift code.

import Foundation
import Networking

/// Collection of basic networking examples demonstrating core HTTP operations
public struct BasicNetworkingExamples {
  // MARK: - Public Interface

  /// Runs all basic networking examples
  public static func runAll() async {
    print("\n📡 Basic Networking Examples")
    print("-" * 30)

    await simpleGETRequest()
    await postRequestWithJSON()
    await headRequest()
    await downloadLargeFile()
    await handleBasicAuthentication()
    await workWithQueryParameters()
  }

  // MARK: - GET Requests

  /// Demonstrates the simplest possible GET request
  ///
  /// Shows:
  /// - Basic client creation
  /// - Simple GET request
  /// - Response handling
  /// - Error management
  public static func simpleGETRequest() async {
    print("🔹 Simple GET Request")

    do {
      // Create a basic HTTP client
      let client = HTTPClient()

      // Make a simple GET request
      let request = HTTPRequest.get("https://httpbin.org/get")
      let response = try await client.send(request)

      print("   Status: \(response.status)")
      print("   Headers: \(response.headers.count) headers")

      if let body = response.body {
        let bodyString = String(data: body, encoding: .utf8) ?? "Invalid UTF-8"
        print("   Body: \(bodyString.prefix(100))...")
      }
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  /// Shows how to work with query parameters in GET requests
  public static func workWithQueryParameters() async {
    print("🔹 GET Request with Query Parameters")

    do {
      let client = HTTPClient()

      // Method 1: URL with query string
      let request1 = HTTPRequest.get("https://httpbin.org/get?param1=value1&param2=value2")
      let response1 = try await client.send(request1)
      print("   Method 1 - Status: \(response1.status)")

      // Method 2: Using URL components (recommended for dynamic parameters)
      var components = URLComponents(string: "https://httpbin.org/get")!
      components.queryItems = [
        URLQueryItem(name: "search", value: "swift networking"),
        URLQueryItem(name: "limit", value: "10"),
        URLQueryItem(name: "offset", value: "0"),
      ]

      guard let url = components.url else {
        print("   ❌ Invalid URL")
        return
      }

      let request2 = HTTPRequest.get(url.absoluteString)
      let response2 = try await client.send(request2)
      print("   Method 2 - Status: \(response2.status)")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - POST Requests

  /// Demonstrates POST requests with JSON data
  ///
  /// Shows:
  /// - JSON serialization
  /// - Content-Type headers
  /// - POST request creation
  /// - Response parsing
  public static func postRequestWithJSON() async {
    print("🔹 POST Request with JSON")

    do {
      let client = HTTPClient()

      // Create JSON data
      let userData =
        [
          "name": "John Doe",
          "email": "john@example.com",
          "age": 30,
        ] as [String: Any]

      let jsonData = try JSONSerialization.data(withJSONObject: userData)

      // Create POST request
      var request = HTTPRequest.post("https://httpbin.org/post")
      request.body = jsonData
      request.headers["Content-Type"] = "application/json"

      let response = try await client.send(request)

      print("   Status: \(response.status)")
      print("   Request sent successfully")

      // Parse response
      if let responseData = response.body,
        let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any]
      {
        print("   Server echoed our data: \(json["json"] != nil)")
      }
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Other HTTP Methods

  /// Demonstrates HEAD requests for metadata
  ///
  /// HEAD requests return only headers, no body - useful for:
  /// - Checking if a resource exists
  /// - Getting content length before download
  /// - Checking last-modified dates
  public static func headRequest() async {
    print("🔹 HEAD Request")

    do {
      let client = HTTPClient()
      let request = HTTPRequest.head("https://httpbin.org/json")
      let response = try await client.send(request)

      print("   Status: \(response.status)")
      print("   Content-Length: \(response.headers["Content-Length"] ?? "Unknown")")
      print("   Content-Type: \(response.headers["Content-Type"] ?? "Unknown")")
      print("   Body should be nil: \(response.body == nil)")
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - File Operations

  /// Demonstrates downloading larger files
  ///
  /// Shows:
  /// - Binary data handling
  /// - Content-Length processing
  /// - Basic progress information
  public static func downloadLargeFile() async {
    print("🔹 Download Large File")

    do {
      let client = HTTPClient()
      let request = HTTPRequest.get("https://httpbin.org/bytes/1024")
      let response = try await client.send(request)

      print("   Status: \(response.status)")

      if let data = response.body {
        print("   Downloaded \(data.count) bytes")
        print("   Content-Type: \(response.headers["Content-Type"] ?? "Unknown")")

        // Basic validation
        let expectedSize = Int(response.headers["Content-Length"] ?? "0") ?? 0
        let actualSize = data.count
        print("   Size match: \(expectedSize == actualSize ? "✅" : "❌")")
      }
    } catch {
      print("   ❌ Error: \(error)")
    }
  }

  // MARK: - Authentication

  /// Demonstrates basic HTTP authentication
  ///
  /// Shows:
  /// - Authorization header creation
  /// - Base64 encoding
  /// - Authentication handling
  public static func handleBasicAuthentication() async {
    print("🔹 Basic Authentication")

    do {
      let client = HTTPClient()

      // httpbin.org/basic-auth/username/password expects basic auth
      let username = "testuser"
      let password = "testpass"

      // Create basic auth header
      let credentials = "\(username):\(password)"
      let credentialsData = credentials.data(using: .utf8)!
      let base64Credentials = credentialsData.base64EncodedString()

      var request = HTTPRequest.get("https://httpbin.org/basic-auth/testuser/testpass")
      request.headers["Authorization"] = "Basic \(base64Credentials)"

      let response = try await client.send(request)

      print("   Status: \(response.status)")
      print("   Authentication: \(response.status == .ok ? "✅ Success" : "❌ Failed")")
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
