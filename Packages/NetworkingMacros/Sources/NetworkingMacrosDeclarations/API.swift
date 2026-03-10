import Foundation

// MARK: - API Protocol Macro

/// Generates an API client implementation for a protocol.
///
/// The `@API` macro transforms a protocol into a complete REST API client by generating
/// an implementation struct that uses the existing `NetworkClient` infrastructure. All
/// endpoint methods defined in the protocol are automatically implemented with proper
/// request construction, parameter handling, and response decoding.
///
/// ## Overview
///
/// Use `@API` to define declarative API clients without writing networking code. The macro
/// generates a `Sendable` implementation struct that integrates with the framework's
/// middleware pipeline, security features, and error handling.
///
/// ## Usage
///
/// ```swift
/// @API(baseURL: "https://api.github.com")
/// protocol GitHubAPI {
///     @GET("/users/{username}")
///     func getUser(username: String) async throws -> User
///
///     @POST("/repos/{owner}/{repo}/issues", body: "issue")
///     func createIssue(
///         owner: String,
///         repo: String,
///         issue: CreateIssueRequest
///     ) async throws -> Issue
/// }
///
/// // Use the generated implementation
/// let api = GitHubAPIImplementation()
/// let user = try await api.getUser(username: "brunogama")
/// ```
///
/// ## Generated Code
///
/// The macro generates an implementation struct with:
/// - `Sendable` conformance for Swift 6 strict concurrency
/// - Private `NetworkClient` property for making requests
/// - Public initializer accepting optional custom `NetworkClient`
/// - Full implementation of all protocol methods
///
/// Example generated code:
/// ```swift
/// struct GitHubAPIImplementation: GitHubAPI, Sendable {
///     private let client: NetworkClient
///
///     public init(client: NetworkClient = .shared) {
///         self.client = client
///     }
///
///     public func getUser(username: String) async throws -> User {
///         let request = HTTPRequest {
///             GET("/users/\(username)")
///             BaseURL("https://api.github.com")
///         }
///         let response = try await client.execute(request)
///         return try response.decode(User.self)
///     }
/// }
/// ```
///
/// ## Parameters
///
/// - Parameter baseURL: The base URL for all API endpoints. Must be a valid URL string.
///                      All endpoint paths are appended to this base URL.
///
/// ## Requirements
///
/// The annotated protocol must:
/// - Contain only method declarations (no properties)
/// - Have all methods marked as `async throws`
/// - Use HTTP method macros (@GET, @POST, etc.) on endpoint methods
/// - Have return types conforming to `Decodable` (except `Void`)
///
/// ## Integration
///
/// Generated implementations:
/// - Use the existing `NetworkClient` for all requests
/// - Inherit all configured middleware (authentication, retry, caching, logging)
/// - Support security features (certificate pinning, SSL validation)
/// - Throw `APIClientError` for failures (HTTP errors, network failures, decoding errors)
/// - Enable dependency injection for testing via custom `NetworkClient`
///
/// ## Performance
///
/// The generated code is identical in performance to hand-written `NetworkClient` code.
/// There is zero runtime overhead from the macro system - all code generation happens
/// at compile time.
///
/// ## Compile-Time Validation
///
/// The macro validates:
/// - Base URL is a non-empty string
/// - All methods are `async throws`
/// - Path parameters match function parameters
/// - Return types conform to `Decodable`
/// - Body parameters conform to `Encodable`
///
/// Validation errors are reported at compile time with clear error messages and
/// Fix-It suggestions.
///
/// ## Related Macros
///
/// - ``GET(_:queryParameters:)``: Define GET endpoints
/// - ``POST(_:body:headers:)``: Define POST endpoints
/// - ``PUT(_:body:headers:)``: Define PUT endpoints
/// - ``PATCH(_:body:headers:)``: Define PATCH endpoints
/// - ``DELETE(_:)``: Define DELETE endpoints
/// - ``DefaultHeaders(_:)``: Configure protocol-level default headers
/// - ``Timeout(_:)``: Configure protocol-level timeout
///
/// ## See Also
///
/// - `NetworkClient`: The underlying HTTP client used by generated implementations
/// - `HTTPRequest`: The request builder DSL used in generated code
/// - `APIClientError`: Errors thrown by generated implementations
///
@attached(member, names: arbitrary)
public macro API(baseURL: String) =
  #externalMacro(module: "NetworkingMacrosPlugin", type: "APIMacro")
