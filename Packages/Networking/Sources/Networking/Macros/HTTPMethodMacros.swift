import Foundation

// MARK: - HTTP Method Macros

/// Marks a method as an HTTP GET request.
///
/// The `@GET` macro generates implementation code that makes an HTTP GET request
/// to the specified path, automatically handling path parameters, query parameters,
/// and response decoding.
///
/// ## Overview
///
/// Use `@GET` on protocol methods to define API endpoints that retrieve data. The macro
/// extracts path parameters from the path template, validates they match function parameters,
/// and generates code to construct and execute the HTTP request.
///
/// ## Usage
///
/// Basic GET request:
/// ```swift
/// @API(baseURL: "https://api.example.com")
/// protocol UserAPI {
///     @GET("/users")
///     func listUsers() async throws -> [User]
/// }
/// ```
///
/// With path parameters:
/// ```swift
/// @GET("/users/{id}")
/// func getUser(id: String) async throws -> User
/// ```
///
/// With query parameters:
/// ```swift
/// @GET("/users", queryParameters: ["role", "status", "limit"])
/// func searchUsers(
///     role: String?,
///     status: String?,
///     limit: Int?
/// ) async throws -> [User]
/// ```
///
/// ## Path Parameters
///
/// Path parameters are specified using `{parameterName}` syntax in the path string.
/// The macro validates at compile time that:
/// - All path parameters exist in the function signature
/// - Parameter names match exactly (case-sensitive)
/// - Parameters are non-optional (required for URL construction)
///
/// Invalid example (compile error):
/// ```swift
/// @GET("/users/{userId}")  // Path expects "userId"
/// func getUser(id: String) // Function has "id" - mismatch!
/// ```
///
/// ## Query Parameters
///
/// Query parameters are listed explicitly in the `queryParameters` array. The macro:
/// - Validates all listed parameters exist in function signature
/// - Generates code to include only non-nil values in query string
/// - Supports optional parameters (only sent when non-nil)
///
/// Example with optional parameters:
/// ```swift
/// @GET("/search", queryParameters: ["q", "page", "limit"])
/// func search(q: String, page: Int?, limit: Int?) async throws -> SearchResults
///
/// // Usage:
/// try await api.search(q: "swift", page: nil, limit: 10)
/// // Generates: GET /search?q=swift&limit=10
/// ```
///
/// ## Return Type
///
/// The return type must conform to `Decodable` for automatic JSON decoding.
/// The macro validates this at compile time.
///
/// Supported return types:
/// - Custom types conforming to `Decodable`
/// - Arrays of `Decodable` types
/// - Optional `Decodable` types
///
/// ## Generated Code
///
/// For a GET endpoint, the macro generates:
/// ```swift
/// func getUser(id: String) async throws -> User {
///     let request = HTTPRequest {
///         GET("/users/\(id)")
///         BaseURL("https://api.example.com")
///     }
///     let response = try await client.execute(request)
///     return try response.decode(User.self)
/// }
/// ```
///
/// ## Parameters
///
/// - Parameter path: The endpoint path relative to base URL. May include `{param}` placeholders.
/// - Parameter queryParameters: Array of function parameter names to include as query parameters.
///                               Defaults to empty array.
///
/// ## Requirements
///
/// The annotated method must:
/// - Be declared in a protocol with `@API` macro
/// - Be marked as `async throws`
/// - Have a return type conforming to `Decodable`
/// - Have all path parameters present in function signature
/// - Have all query parameters present in function signature
///
/// ## Error Handling
///
/// Generated code throws `APIClientError` for:
/// - HTTP errors (4xx, 5xx status codes)
/// - Network failures (connectivity issues)
/// - JSON decoding failures
///
/// ## See Also
///
/// - ``API(baseURL:)``: Define the API protocol
/// - ``POST(_:body:headers:)``: Create resources
/// - ``PUT(_:body:headers:)``: Update resources
/// - ``DELETE(_:)``: Delete resources
///
@attached(peer)
public macro GET(
  _ path: String,
  queryParameters: [String] = []
) = #externalMacro(module: "NetworkingMacrosPlugin", type: "GETMacro")

/// Marks a method as an HTTP POST request.
///
/// The `@POST` macro generates implementation code that makes an HTTP POST request
/// with automatic request body encoding and response decoding.
///
/// ## Usage
///
/// ```swift
/// @POST("/users", body: "user")
/// func createUser(user: CreateUserRequest) async throws -> User
/// ```
///
/// With path parameters:
/// ```swift
/// @POST("/orgs/{orgId}/users", body: "user")
/// func createOrgUser(orgId: String, user: CreateUserRequest) async throws -> User
/// ```
///
/// ## Parameters
///
/// - Parameter path: The endpoint path relative to base URL
/// - Parameter body: Name of the function parameter to use as request body
/// - Parameter headers: Optional dictionary of custom headers for this request
///
@attached(peer)
public macro POST(
  _ path: String,
  body: String,
  headers: [String: String] = [:]
) = #externalMacro(module: "NetworkingMacrosPlugin", type: "POSTMacro")

/// Marks a method as an HTTP PUT request.
///
/// The `@PUT` macro generates implementation code for full resource updates.
///
/// ## Usage
///
/// ```swift
/// @PUT("/users/{id}", body: "user")
/// func updateUser(id: String, user: User) async throws -> User
/// ```
///
/// ## Parameters
///
/// - Parameter path: The endpoint path relative to base URL
/// - Parameter body: Name of the function parameter to use as request body
/// - Parameter headers: Optional dictionary of custom headers for this request
///
@attached(peer)
public macro PUT(
  _ path: String,
  body: String,
  headers: [String: String] = [:]
) = #externalMacro(module: "NetworkingMacrosPlugin", type: "PUTMacro")

/// Marks a method as an HTTP PATCH request.
///
/// The `@PATCH` macro generates implementation code for partial resource updates.
///
/// ## Usage
///
/// ```swift
/// @PATCH("/users/{id}", body: "updates")
/// func patchUser(id: String, updates: UserUpdates) async throws -> User
/// ```
///
/// ## Parameters
///
/// - Parameter path: The endpoint path relative to base URL
/// - Parameter body: Name of the function parameter to use as request body
/// - Parameter headers: Optional dictionary of custom headers for this request
///
@attached(peer)
public macro PATCH(
  _ path: String,
  body: String,
  headers: [String: String] = [:]
) = #externalMacro(module: "NetworkingMacrosPlugin", type: "PATCHMacro")

/// Marks a method as an HTTP DELETE request.
///
/// The `@DELETE` macro generates implementation code for resource deletion.
///
/// ## Usage
///
/// ```swift
/// @DELETE("/users/{id}")
/// func deleteUser(id: String) async throws
/// ```
///
/// With response body:
/// ```swift
/// @DELETE("/users/{id}")
/// func deleteUser(id: String) async throws -> DeletionConfirmation
/// ```
///
/// ## Parameters
///
/// - Parameter path: The endpoint path relative to base URL
///
@attached(peer)
public macro DELETE(_ path: String) =
  #externalMacro(module: "NetworkingMacrosPlugin", type: "DELETEMacro")
