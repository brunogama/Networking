// MARK: - Modern Networking Framework
// Swift 6 compliant networking framework with async/await and structured concurrency

@_exported import Foundation

// MARK: - Core Types
// Re-export all public types for easy importing

// Core HTTP Types
public typealias HTTPResult = Result<HTTPResponse, HTTPError>

// MARK: - Framework Version
public enum ModernNetworking {
  public static let version = "1.0.0"
  public static let swiftVersion = "6.0"
}

/*
 Example usage:

 ```swift
 import ModernNetworking

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
