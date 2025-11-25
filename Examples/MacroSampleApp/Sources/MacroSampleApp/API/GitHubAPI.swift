import Foundation
import Networking

// Note: The networking macros have a limitation where @Path, @Query, @Body
// cannot be attached to function parameters in Swift macros.
// This file shows the manual implementation that the macros WOULD generate.

/// GitHub API client using the manual RequestBuilder pattern
struct GitHubClient {
  private let client: HTTPClient
  // swiftlint:disable:next force_unwrapping
  private let baseURL = URL(string: "https://api.github.com")!

  init(client: HTTPClient = NetworkClient()) {
    self.client = client
  }

  /// Fetch a user by username
  func getUser(username: String) async throws -> User {
    let request = try HTTPRequest {
      RequestBaseURL(baseURL)
      GET("/users/\(username)")
    }
    let response = try await client.execute(request)
    return try response.chain().decode(User.self).value
  }

  /// Search repositories
  func searchRepositories(
    searchQuery: String,
    perPage: Int,
    page: Int
  ) async throws -> SearchResult<Repository> {
    let request = try HTTPRequest {
      RequestBaseURL(baseURL)
      GET("/search/repositories")
      QueryParam("q", searchQuery)
      QueryParam("per_page", perPage)
      QueryParam("page", page)
    }
    let response = try await client.execute(request)
    return try response.chain().decode(SearchResult<Repository>.self).value
  }

  /// Get repository details
  func getRepository(owner: String, repo: String) async throws -> Repository {
    let request = try HTTPRequest {
      RequestBaseURL(baseURL)
      GET("/repos/\(owner)/\(repo)")
    }
    let response = try await client.execute(request)
    return try response.chain().decode(Repository.self).value
  }

  /// Get user's repositories
  func getUserRepos(
    username: String,
    perPage: Int,
    sort: String
  ) async throws -> [Repository] {
    let request = try HTTPRequest {
      RequestBaseURL(baseURL)
      GET("/users/\(username)/repos")
      QueryParam("per_page", perPage)
      QueryParam("sort", sort)
    }
    let response = try await client.execute(request)
    return try response.chain().decode([Repository].self).value
  }
}
