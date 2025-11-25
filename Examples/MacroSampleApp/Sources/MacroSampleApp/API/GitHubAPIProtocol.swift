import Foundation
import Networking

// MARK: - GitHub API Protocol with Macros

/// GitHub API defined using the @API macro with declarative HTTP method annotations.
///
/// This demonstrates the new macro syntax where:
/// - Path parameters are auto-detected from `{placeholder}` in the URL
/// - Query parameters are all remaining parameters (or explicitly mapped)
/// - Body and headers are explicitly specified in the macro
@API(baseURL: "https://api.github.com")
protocol GitHubAPI {
  /// Fetch a GitHub user by username
  /// - `username` is auto-detected as path param from `{username}` placeholder
  @GET("/users/{username}")
  func getUser(username: String) async throws -> User

  /// Search repositories with custom query parameter names
  /// - `searchQuery` maps to `q` in the API
  /// - `perPage` maps to `per_page` in the API
  /// - `page` uses its name as-is
  @GET("/search/repositories", query: ["searchQuery": "q", "perPage": "per_page"])
  func searchRepositories(
    searchQuery: String,
    perPage: Int,
    page: Int
  ) async throws -> SearchResult<Repository>

  /// Get repository details
  /// - Both `owner` and `repo` are auto-detected as path params
  @GET("/repos/{owner}/{repo}")
  func getRepository(owner: String, repo: String) async throws -> Repository

  /// Get user's repositories with mixed path and query params
  /// - `username` is auto-detected as path param
  /// - `perPage` and `sort` are query params with custom mapping
  @GET("/users/{username}/repos", query: ["perPage": "per_page"])
  func getUserRepos(
    username: String,
    perPage: Int,
    sort: String
  ) async throws -> [Repository]
}
