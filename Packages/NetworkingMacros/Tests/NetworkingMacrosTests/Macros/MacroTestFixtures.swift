import Foundation

/// Common test fixtures and data for macro expansion tests.
///
/// Provides reusable test data including sample protocols, expected expansions,
/// error cases, and edge cases for comprehensive macro testing.
enum MacroTestFixtures {
  // MARK: - Sample Data Models

  static let userModel = """
    struct User: Codable {
      let id: String
      let name: String
      let email: String
    }
    """

  static let postModel = """
    struct Post: Codable {
      let id: String
      let title: String
      let body: String
      let userId: String
    }
    """

  static let createUserRequest = """
    struct CreateUserRequest: Encodable {
      let name: String
      let email: String
    }
    """

  // MARK: - Simple GET Endpoints

  static let simpleGETProtocol = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @GET(.path("/users/{id}"))
      func getUser(id: String) async throws -> User
    }
    """

  static let simpleGETExpected = """
    struct UserAPIImplementation: UserAPI, Sendable {
      private let client: NetworkClient

      init(client: NetworkClient = .shared) {
        self.client = client
      }

      func getUser(id: String) async throws -> User {
        let request = HTTPRequest {
          GET("/users/\\(id)")
          BaseURL("https://api.example.com")
        }
        let response = try await client.execute(request)
        return try response.decode(User.self)
      }
    }
    """

  // MARK: - GET with Query Parameters

  static let getWithQueryParamsProtocol = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @GET(.path("/users"), queryParameters: [.parameter("role"), .parameter("limit")])
      func listUsers(role: String?, limit: Int?) async throws -> [User]
    }
    """

  static let getWithQueryParamsExpected = """
    struct UserAPIImplementation: UserAPI, Sendable {
      private let client: NetworkClient

      init(client: NetworkClient = .shared) {
        self.client = client
      }

      func listUsers(role: String?, limit: Int?) async throws -> [User] {
        var queryItems: [String: String] = [:]
        if let role = role {
          queryItems["role"] = String(role)
        }
        if let limit = limit {
          queryItems["limit"] = String(limit)
        }

        let request = HTTPRequest {
          GET("/users")
          BaseURL("https://api.example.com")
          if !queryItems.isEmpty {
            QueryParams(queryItems)
          }
        }
        let response = try await client.execute(request)
        return try response.decode([User].self)
      }
    }
    """

  // MARK: - POST with Body

  static let postWithBodyProtocol = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @POST(.path("/users"), body: .parameter("user"))
      func createUser(user: CreateUserRequest) async throws -> User
    }
    """

  static let postWithBodyExpected = """
    struct UserAPIImplementation: UserAPI, Sendable {
      private let client: NetworkClient

      init(client: NetworkClient = .shared) {
        self.client = client
      }

      func createUser(user: CreateUserRequest) async throws -> User {
        let request = HTTPRequest {
          POST("/users")
          BaseURL("https://api.example.com")
          JSONBody(user)
          ContentType(.json)
        }
        let response = try await client.execute(request)
        return try response.decode(User.self)
      }
    }
    """

  // MARK: - PUT with Path Params and Body

  static let putWithPathAndBodyProtocol = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @PUT(.path("/users/{id}"), body: .parameter("user"))
      func updateUser(id: String, user: User) async throws -> User
    }
    """

  // MARK: - DELETE Endpoint

  static let deleteProtocol = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @DELETE(.path("/users/{id}"))
      func deleteUser(id: String) async throws
    }
    """

  static let deleteExpected = """
    struct UserAPIImplementation: UserAPI, Sendable {
      private let client: NetworkClient

      init(client: NetworkClient = .shared) {
        self.client = client
      }

      func deleteUser(id: String) async throws {
        let request = HTTPRequest {
          DELETE("/users/\\(id)")
          BaseURL("https://api.example.com")
        }
        _ = try await client.execute(request)
      }
    }
    """

  // MARK: - Configuration Macros

  static let protocolWithHeaders = """
    @API(baseURL: .absolute("https://api.example.com"))
    @DefaultHeaders([.named("X-API-Version"): .literal("v1"), .named("Accept"): .literal("application/json")])
    protocol UserAPI {
      @GET(.path("/users/{id}"))
      func getUser(id: String) async throws -> User
    }
    """

  static let protocolWithTimeout = """
    @API(baseURL: .absolute("https://api.example.com"))
    @Timeout(.seconds(30.0))
    protocol UserAPI {
      @GET(.path("/users/{id}"))
      func getUser(id: String) async throws -> User
    }
    """

  // MARK: - Complex Multi-Method Protocol

  static let complexProtocol = """
    @API(baseURL: .absolute("https://api.example.com"))
    @DefaultHeaders([.named("X-API-Version"): .literal("v1")])
    @Timeout(.seconds(15.0))
    protocol UserAPI {
      @GET(.path("/users"), queryParameters: [.parameter("role")])
      func listUsers(role: String?) async throws -> [User]

      @GET(.path("/users/{id}"))
      func getUser(id: String) async throws -> User

      @POST(.path("/users"), body: .parameter("request"))
      func createUser(request: CreateUserRequest) async throws -> User

      @PUT(.path("/users/{id}"), body: .parameter("user"))
      func updateUser(id: String, user: User) async throws -> User

      @DELETE(.path("/users/{id}"))
      func deleteUser(id: String) async throws
    }
    """

  // MARK: - Error Cases

  /// Missing async keyword
  static let missingAsyncError = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @GET(.path("/users/{id}"))
      func getUser(id: String) throws -> User
    }
    """

  /// Missing throws keyword
  static let missingThrowsError = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @GET(.path("/users/{id}"))
      func getUser(id: String) async -> User
    }
    """

  /// Path parameter mismatch
  static let pathParameterMismatchError = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @GET(.path("/users/{userId}"))
      func getUser(id: String) async throws -> User
    }
    """

  /// Body parameter not found
  static let bodyParameterNotFoundError = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @POST(.path("/users"), body: .parameter("request"))
      func createUser(user: User) async throws -> User
    }
    """

  /// Query parameter not found
  static let queryParameterNotFoundError = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @GET(.path("/users"), queryParameters: [.parameter("role"), .parameter("status")])
      func listUsers(role: String?) async throws -> [User]
    }
    """

  /// Multiple HTTP methods
  static let multipleHTTPMethodsError = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @GET(.path("/users/{id}"))
      @POST(.path("/users/{id}"))
      func handleUser(id: String) async throws -> User
    }
    """

  /// Invalid path template (unmatched braces)
  static let invalidPathTemplateError = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @GET(.path("/users/{id"))
      func getUser(id: String) async throws -> User
    }
    """

  /// Invalid path template (empty parameter)
  static let emptyParameterError = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @GET(.path("/users/{}"))
      func getUser(id: String) async throws -> User
    }
    """

  // MARK: - Edge Cases

  /// No parameters
  static let noParametersProtocol = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @GET(.path("/users"))
      func listUsers() async throws -> [User]
    }
    """

  /// Void return type
  static let voidReturnProtocol = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol UserAPI {
      @DELETE(.path("/users/{id}"))
      func deleteUser(id: String) async throws
    }
    """

  /// Multiple path parameters
  static let multiplePathParamsProtocol = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol PostAPI {
      @GET(.path("/users/{userId}/posts/{postId}"))
      func getPost(userId: String, postId: String) async throws -> Post
    }
    """

  /// Mixed path and query parameters
  static let mixedParametersProtocol = """
    @API(baseURL: .absolute("https://api.example.com"))
    protocol PostAPI {
      @GET(.path("/users/{userId}/posts"), queryParameters: [.parameter("status"), .parameter("limit")])
      func listUserPosts(
        userId: String,
        status: String?,
        limit: Int?
      ) async throws -> [Post]
    }
    """

  // MARK: - Real-World Examples

  /// GitHub API-style protocol
  static let githubStyleProtocol = """
    @API(baseURL: .absolute("https://api.github.com"))
    @DefaultHeaders([.named("Accept"): .literal("application/vnd.github+json"), .named("X-GitHub-Api-Version"): .literal("2022-11-28")])
    protocol GitHubAPI {
      @GET(.path("/users/{username}"))
      func getUser(username: String) async throws -> GitHubUser

      @GET(.path("/users/{username}/repos"), queryParameters: [.parameter("sort"), .parameter("direction")])
      func listRepos(
        username: String,
        sort: String?,
        direction: String?
      ) async throws -> [GitHubRepo]

      @POST(.path("/repos/{owner}/{repo}/issues"), body: .parameter("issue"))
      func createIssue(
        owner: String,
        repo: String,
        issue: CreateIssueRequest
      ) async throws -> GitHubIssue
    }
    """
}
