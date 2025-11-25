import Foundation
import Networking

// Note: The networking macros have a limitation where @Path, @Query, @Body
// cannot be attached to function parameters in Swift macros.
// This file shows the manual implementation that the macros WOULD generate.

/// JSONPlaceholder API client using the manual RequestBuilder pattern
struct JSONPlaceholderClient {
  private let client: HTTPClient
  // swiftlint:disable:next force_unwrapping
  private let baseURL = URL(string: "https://jsonplaceholder.typicode.com")!

  init(client: HTTPClient = NetworkClient()) {
    self.client = client
  }

  /// Get all posts
  func getPosts() async throws -> [Post] {
    let request = try HTTPRequest {
      RequestBaseURL(baseURL)
      GET("/posts")
    }
    let response = try await client.execute(request)
    return try response.chain().decode([Post].self).value
  }

  /// Get single post by ID
  func getPost(id: Int) async throws -> Post {
    let request = try HTTPRequest {
      RequestBaseURL(baseURL)
      GET("/posts/\(id)")
    }
    let response = try await client.execute(request)
    return try response.chain().decode(Post.self).value
  }

  /// Get posts by user
  func getPostsByUser(userId: Int) async throws -> [Post] {
    let request = try HTTPRequest {
      RequestBaseURL(baseURL)
      GET("/posts")
      QueryParam("userId", userId)
    }
    let response = try await client.execute(request)
    return try response.chain().decode([Post].self).value
  }

  /// Create a new post
  func createPost(post: Post) async throws -> Post {
    let request = try HTTPRequest {
      RequestBaseURL(baseURL)
      POST("/posts")
      JSONBody(post)
    }
    let response = try await client.execute(request)
    return try response.chain().decode(Post.self).value
  }
}
