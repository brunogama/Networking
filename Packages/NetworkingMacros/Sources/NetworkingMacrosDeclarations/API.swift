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
/// @API(baseURL: .absolute("https://api.github.com"))
/// protocol GitHubAPI {
///     @GET(.path("/users/{username}"))
///     func getUser(username: String) async throws -> User
///
///     @POST(.path("/repos/{owner}/{repo}/issues"))
///     @Body(.parameter("issue"))
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
/// - Private `HTTPClient` property for making requests
/// - Initializer accepting an injected `HTTPClient`
/// - Full implementation of all protocol methods
///
/// Example generated code:
/// ```swift
/// struct GitHubAPIImplementation: GitHubAPI, Sendable {
///     private let client: any HTTPClient
///     private let baseURL = BaseURLText(rawValue: "https://api.github.com")
///     private let defaultHeaders: HTTPHeaders = [:]
///     private let defaultTimeout = RequestTimeout(rawValue: 30)
///
///     init(client: any HTTPClient = NetworkClient()) {
///         self.client = client
///     }
///
///     func getUser(username: String) async throws -> User {
///         let path = "/users/\(username)"
///         guard let url = HTTPRequestURL(
///             BaseURLText(rawValue: baseURL.rawValue + path)
///         ) else {
///             throw URLError(.badURL)
///         }
///         let request = HTTPRequest(
///             method: .get,
///             url: url,
///             headers: defaultHeaders,
///             timeout: defaultTimeout
///         )
///         let response = try await client.execute(request)
///         guard let body = response.body else {
///             throw DecodingError.dataCorrupted(
///                 .init(codingPath: [], debugDescription: "Response body is empty")
///             )
///         }
///         return try JSONDecoder().decode(User.self, from: body.rawValue)
///     }
/// }
/// ```
///
/// ## Parameters
///
/// - Parameter baseURL: The base URL for all API endpoints. Use `.absolute("https://...")`.
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
/// Return and body types are checked by the Swift compiler where generated decoding and
/// encoding call `Decodable` and `Encodable` APIs.
///
/// Validation errors are reported at compile time with clear error messages and
/// Fix-It suggestions.
///
/// ## Related Macros
///
/// - ``GET(_:queryParameters:)``: Define GET endpoints
/// - ``POST(_:body:headers:queryParameters:)``: Define POST endpoints
/// - ``PUT(_:body:headers:queryParameters:)``: Define PUT endpoints
/// - ``PATCH(_:body:headers:queryParameters:)``: Define PATCH endpoints
/// - ``DELETE(_:queryParameters:)``: Define DELETE endpoints
/// - ``DefaultHeaders(_:)``: Configure protocol-level default headers
/// - ``Timeout(_:)``: Configure protocol-level timeout
///
/// ## See Also
///
/// - `NetworkClient`: The underlying HTTP client used by generated implementations
/// - `HTTPRequest`: The request type used by generated implementations
///
@attached(peer, names: suffixed(Implementation))
public macro API(baseURL: APIBaseURL) =
  #externalMacro(module: "NetworkingMacrosPlugin", type: "APIMacro")
