import Foundation
import Networking

// MARK: - JSONPlaceholder API Protocol with Macros

/// JSONPlaceholder API defined using the @API macro.
///
/// This demonstrates:
/// - Simple GET requests with path parameters
/// - Query parameter filtering
/// - POST requests with body parameter
@API(baseURL: "https://jsonplaceholder.typicode.com")
protocol JSONPlaceholderAPI {
  /// Get all posts
  @GET("/posts")
  func getPosts() async throws -> [Post]

  /// Get single post by ID
  /// - `id` is auto-detected as path param from `{id}` placeholder
  @GET("/posts/{id}")
  func getPost(id: Int) async throws -> Post

  /// Get posts filtered by user
  /// - `userId` becomes a query parameter
  @GET("/posts")
  func getPostsByUser(userId: Int) async throws -> [Post]

  /// Create a new post
  /// - `post` is specified as the JSON body
  @POST("/posts", body: "post")
  func createPost(post: Post) async throws -> Post
}
