/// Configuration macros for API client protocols.
///
/// These macros allow applying protocol-level configuration that affects all
/// endpoints within an API client definition.
///
/// ## Topics
///
/// ### Protocol Configuration
/// - ``DefaultHeaders(_:)``
/// - ``Timeout(_:)``

/// Applies default headers to all endpoints in an API protocol.
///
/// Default headers are applied to every request made by the API client,
/// unless explicitly overridden by method-level headers.
///
/// Example:
/// ```swift
/// @API(baseURL: "https://api.example.com")
/// @DefaultHeaders([
///   "Accept": "application/json",
///   "User-Agent": "MyApp/1.0"
/// ])
/// protocol UserAPI {
///   @GET("/users/{id}")
///   func getUser(id: String) async throws -> User
/// }
/// ```
///
/// The generated implementation will include these headers in every request:
/// ```swift
/// struct UserAPIImplementation: UserAPI {
///   func getUser(id: String) async throws -> User {
///     var request = HTTPRequest(method: .GET, path: "/users/\(id)")
///     request.addHeader(name: "Accept", value: "application/json")
///     request.addHeader(name: "User-Agent", value: "MyApp/1.0")
///     // ... rest of implementation
///   }
/// }
/// ```
///
/// - Parameter headers: Dictionary of header names and values to apply to all requests.
///
/// - Note: Method-level headers (specified via `@GET(headers:)` etc.) take
///   precedence over default headers when there are conflicts.
@attached(member)
public macro DefaultHeaders(_ headers: [String: String]) =
  #externalMacro(module: "NetworkingMacros", type: "DefaultHeadersMacro")

/// Sets the default timeout for all endpoints in an API protocol.
///
/// The timeout applies to all requests made by the API client,
/// unless explicitly overridden by method-level configuration.
///
/// Example:
/// ```swift
/// @API(baseURL: "https://api.example.com")
/// @Timeout(30.0)
/// protocol UserAPI {
///   @GET("/users/{id}")
///   func getUser(id: String) async throws -> User
/// }
/// ```
///
/// The generated implementation will configure timeout for every request:
/// ```swift
/// struct UserAPIImplementation: UserAPI {
///   func getUser(id: String) async throws -> User {
///     var request = HTTPRequest(method: .GET, path: "/users/\(id)")
///     request.timeout = 30.0
///     // ... rest of implementation
///   }
/// }
/// ```
///
/// - Parameter seconds: Timeout duration in seconds. Must be positive.
///
/// - Note: Individual methods can override this timeout by specifying
///   their own timeout configuration.
@attached(member)
public macro Timeout(_ seconds: Double) =
  #externalMacro(module: "NetworkingMacros", type: "TimeoutMacro")
