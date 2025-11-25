import Foundation

// MARK: - API Generation Macros

/// Generates an HTTP API client implementation for a protocol.
///
/// The `@API` macro generates a concrete implementation struct for the annotated protocol.
/// Each method in the protocol must be annotated with an HTTP method macro (`@GET`, `@POST`, etc.).
///
/// ## Basic Usage
///
/// ```swift
/// @API(baseURL: "https://api.example.com")
/// protocol UserAPI {
///     @GET("/users/{id}")
///     func getUser(id: String) async throws -> User
///
///     @POST("/users", body: "user")
///     func createUser(user: User) async throws -> User
/// }
///
/// // Use the generated implementation
/// let api = UserAPIImplementation()
/// let user = try await api.getUser(id: "123")
/// ```
///
/// ## Parameter Handling
///
/// - **Path parameters**: Auto-detected from `{placeholder}` in the path. Parameter names must match.
/// - **Query parameters**: All parameters not used as path, body, or headers become query params.
/// - **Body**: Specify with `body: "paramName"` - the parameter will be JSON-encoded.
/// - **Headers**: Specify with `headers: ["paramName": "Header-Name"]` dictionary.
/// - **Query name mapping**: Use `query: ["paramName": "api_name"]` when API expects different names.
///
/// ## Complete Example
///
/// ```swift
/// @API(baseURL: "https://api.github.com")
/// protocol GitHubAPI {
///     // Path param auto-detected, remaining params become query
///     @GET("/users/{username}/repos")
///     func getUserRepos(username: String, perPage: Int, sort: String) async throws -> [Repo]
///
///     // Custom query parameter names
///     @GET("/search/repositories", query: ["searchQuery": "q", "perPage": "per_page"])
///     func search(searchQuery: String, perPage: Int, page: Int) async throws -> SearchResult
///
///     // POST with body
///     @POST("/repos/{owner}/{repo}/issues", body: "issue")
///     func createIssue(owner: String, repo: String, issue: Issue) async throws -> Issue
///
///     // With authorization header
///     @GET("/user", headers: ["token": "Authorization"])
///     func getAuthenticatedUser(token: String) async throws -> User
/// }
/// ```
@attached(peer, names: suffixed(Implementation))
public macro API(baseURL: String) =
  #externalMacro(module: "NetworkingMacros", type: "APIMacro")

// MARK: - HTTP Method Macros

/// Marks a method as a GET request.
///
/// - Parameters:
///   - path: The URL path, may contain `{placeholder}` for path parameters
///   - query: Optional dictionary mapping parameter names to query string keys
///   - headers: Optional dictionary mapping parameter names to header names
///
/// Path parameters are auto-detected from `{placeholder}` syntax in the path.
/// Remaining parameters (not path, body, or headers) become query parameters.
///
/// ```swift
/// @GET("/users/{id}")
/// func getUser(id: String) async throws -> User
///
/// @GET("/search", query: ["searchTerm": "q"])
/// func search(searchTerm: String, limit: Int) async throws -> Results
/// ```
@attached(peer)
public macro GET(
  _ path: String,
  query: [String: String] = [:],
  headers: [String: String] = [:]
) = #externalMacro(module: "NetworkingMacros", type: "GETMacro")

/// Marks a method as a POST request.
///
/// - Parameters:
///   - path: The URL path, may contain `{placeholder}` for path parameters
///   - body: Optional parameter name to use as the JSON request body
///   - query: Optional dictionary mapping parameter names to query string keys
///   - headers: Optional dictionary mapping parameter names to header names
///
/// ```swift
/// @POST("/users", body: "user")
/// func createUser(user: CreateUserRequest) async throws -> User
///
/// @POST("/repos/{owner}/{repo}/issues", body: "issue", headers: ["token": "Authorization"])
/// func createIssue(owner: String, repo: String, issue: Issue, token: String) async throws -> Issue
/// ```
@attached(peer)
public macro POST(
  _ path: String,
  body: String? = nil,
  query: [String: String] = [:],
  headers: [String: String] = [:]
) = #externalMacro(module: "NetworkingMacros", type: "POSTMacro")

/// Marks a method as a PUT request.
///
/// - Parameters:
///   - path: The URL path, may contain `{placeholder}` for path parameters
///   - body: Optional parameter name to use as the JSON request body
///   - query: Optional dictionary mapping parameter names to query string keys
///   - headers: Optional dictionary mapping parameter names to header names
///
/// ```swift
/// @PUT("/users/{id}", body: "user")
/// func updateUser(id: String, user: UpdateUserRequest) async throws -> User
/// ```
@attached(peer)
public macro PUT(
  _ path: String,
  body: String? = nil,
  query: [String: String] = [:],
  headers: [String: String] = [:]
) = #externalMacro(module: "NetworkingMacros", type: "PUTMacro")

/// Marks a method as a DELETE request.
///
/// - Parameters:
///   - path: The URL path, may contain `{placeholder}` for path parameters
///   - body: Optional parameter name to use as the JSON request body
///   - query: Optional dictionary mapping parameter names to query string keys
///   - headers: Optional dictionary mapping parameter names to header names
///
/// ```swift
/// @DELETE("/users/{id}")
/// func deleteUser(id: String) async throws
///
/// @DELETE("/items", body: "items")
/// func deleteItems(items: DeleteRequest) async throws
/// ```
@attached(peer)
public macro DELETE(
  _ path: String,
  body: String? = nil,
  query: [String: String] = [:],
  headers: [String: String] = [:]
) = #externalMacro(module: "NetworkingMacros", type: "DELETEMacro")

/// Marks a method as a PATCH request.
///
/// - Parameters:
///   - path: The URL path, may contain `{placeholder}` for path parameters
///   - body: Optional parameter name to use as the JSON request body
///   - query: Optional dictionary mapping parameter names to query string keys
///   - headers: Optional dictionary mapping parameter names to header names
///
/// ```swift
/// @PATCH("/users/{id}", body: "updates")
/// func patchUser(id: String, updates: PatchUserRequest) async throws -> User
/// ```
@attached(peer)
public macro PATCH(
  _ path: String,
  body: String? = nil,
  query: [String: String] = [:],
  headers: [String: String] = [:]
) = #externalMacro(module: "NetworkingMacros", type: "PATCHMacro")

// MARK: - Caching Macros

/// Marks a method as cacheable with optional configuration.
///
/// Usage:
/// ```swift
/// @API(baseURL: "https://api.example.com")
/// protocol UserAPI {
///     @GET("/users/{id}")
///     @Cacheable(ttl: 600, tags: ["user"])
///     func getUser(@Path id: String) async throws -> User
/// }
/// ```
@attached(peer)
public macro Cacheable(ttl: TimeInterval? = nil, tags: [String] = [], key: String? = nil) =
  #externalMacro(module: "NetworkingMacros", type: "CacheableMacro")

/// Marks a method as causing cache invalidation.
///
/// Usage:
/// ```swift
/// @API(baseURL: "https://api.example.com")
/// protocol UserAPI {
///     @POST("/users")
///     @CacheInvalidation(tags: ["user"], pattern: "users/*")
///     func createUser(@Body user: User) async throws -> User
/// }
/// ```
@attached(peer)
public macro CacheInvalidation(tags: [String] = [], pattern: String? = nil, keys: [String] = []) =
  #externalMacro(module: "NetworkingMacros", type: "CacheInvalidationMacro")
