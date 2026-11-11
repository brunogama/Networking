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
/// // The factory returns the protocol, not the implementation.
/// let api: any GitHubAPI = GitHubAPIFactory.make()
/// let user = try await api.getUser(username: "brunogama")
/// ```
///
/// ## Generated Code
///
/// The macro generates a private `Sendable` implementation and a factory named after
/// the protocol. The factory's `make(client:codec:)` method returns the protocol and accepts
/// any `HTTPClient` and a reusable `JSONCodec` for dependency injection.
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
/// - Enable dependency injection through the factory's `HTTPClient` argument
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
/// Validation errors are reported at compile time with clear messages and stable diagnostic IDs.
///
/// ## Related Macros
///
/// - ``GET(_:queryParameters:)``: Define GET endpoints
/// - ``POST(_:queryParameters:)``: Define POST endpoints
/// - ``PUT(_:queryParameters:)``: Define PUT endpoints
/// - ``PATCH(_:queryParameters:)``: Define PATCH endpoints
/// - ``DELETE(_:queryParameters:)``: Define DELETE endpoints
/// - ``DefaultHeaders(_:)``: Configure protocol-level default headers
/// - ``Timeout(_:)``: Configure protocol-level timeout
///
/// ## See Also
///
/// - `NetworkClient`: The underlying HTTP client used by generated implementations
/// - `HTTPRequest`: The request type used by generated implementations
///
@attached(peer, names: suffixed(Implementation), suffixed(Factory))
public macro API(baseURL: APIBaseURL) =
  #externalMacro(module: "NetworkingMacrosPlugin", type: "APIMacro")
