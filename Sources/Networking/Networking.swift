// MARK: - Networking Framework
// Swift 6 compliant networking framework with async/await and structured concurrency

@_exported import Foundation

// MARK: - Core Types
// Re-export all public types for easy importing

// Core HTTP Types
public typealias HTTPResult = Result<HTTPResponse, HTTPError>

// MARK: - Testing Support
#if DEBUG || TESTING || TEST
// Make testing utilities available for users
// Users can import Networking and access MockURLProtocol, MockNetworkClient, etc.
// These are only available in debug/test builds
#endif

// MARK: - Framework Version
public enum Networking {
  public static let version = "1.0.0"
  public static let swiftVersion = "6.0"
  public static let supportsTesting = true
}

/*
 Example usage:

 ```swift
 import Networking

 // Simple client with DSL
 let client = NetworkClient {
     BaseURL("https://api.example.com")
     EnableLogging()
     EnableRetry()
     DefaultHeader("User-Agent", "MyApp/1.0")
 }

 // Make requests with builder pattern
 let response = try await client.execute {
     GET("/users/123")
     BearerAuth(token)
     Timeout(15.0)
 }

 let user: User = try response.decode(User.self)

 // Or use generated API client
 @API(baseURL: "https://api.example.com")
 protocol UserAPI {
     @GET("/users/{id}")
     func getUser(@Path id: String) async throws -> User

     @POST("/users")
     func createUser(@Body user: User) async throws -> User
 }

 let userAPI = UserAPIImplementation()
 let user = try await userAPI.getUser(id: "123")
 ```
 */
