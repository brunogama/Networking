import Foundation

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
/// - ``Interceptors(_:)``

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

/// Configures request/response interceptors for all endpoints in an API protocol.
///
/// Interceptors execute before/after HTTP requests to handle cross-cutting concerns
/// like authentication, logging, retry logic, and caching. They are executed in the
/// order specified in the array.
///
/// Example:
/// ```swift
/// @API(baseURL: "https://api.example.com")
/// @Interceptors([
///   AuthenticationInterceptor(tokenProvider: .shared),
///   LoggingInterceptor(),
///   RetryInterceptor(maxAttempts: 3)
/// ])
/// protocol UserAPI {
///   @GET("/users/{id}")
///   func getUser(id: String) async throws -> User
/// }
/// ```
///
/// The generated implementation will initialize an interceptor chain and execute
/// interceptors for every request:
/// ```swift
/// struct UserAPIImplementation: UserAPI {
///   private let interceptors: InterceptorChain
///
///   init(client: NetworkClient) {
///     self.client = client
///     self.interceptors = InterceptorChain(
///       requestInterceptors: [
///         AuthenticationInterceptor(tokenProvider: .shared),
///         LoggingInterceptor()
///       ],
///       responseInterceptors: [
///         LoggingInterceptor(),
///         RetryInterceptor(maxAttempts: 3)
///       ]
///     )
///   }
///
///   func getUser(id: String) async throws -> User {
///     var request = HTTPRequest(method: .GET, path: "/users/\(id)")
///     let context = InterceptorContext(path: "/users/\(id)", method: .GET, attemptCount: 0)
///
///     // Execute request interceptors
///     let requestResult = try await interceptors.executeRequestInterceptors(request: &request, context: context)
///     if case .shortCircuit(let response) = requestResult {
///       return try JSONDecoder().decode(User.self, from: response.body ?? Data())
///     }
///
///     // Execute network request
///     let response = try await client.execute(request)
///
///     // Execute response interceptors
///     let responseResult = try await interceptors.executeResponseInterceptors(response: response, context: context)
///     if case .retry = responseResult {
///       // Handle retry logic
///     }
///
///     return try JSONDecoder().decode(User.self, from: response.body ?? Data())
///   }
/// }
/// ```
///
/// - Parameter interceptors: Array of interceptor instances to apply to all requests.
///   Interceptors must conform to either `RequestInterceptor`, `ResponseInterceptor`,
///   or both protocols.
///
/// - Note: Interceptors are executed sequentially in the order they appear in the array.
///   Request interceptors execute before the network call, and response interceptors
///   execute after the network call.
///
/// - Note: All interceptors must be `Sendable` to comply with Swift 6 strict concurrency.
@attached(member)
public macro Interceptors(_ interceptors: [Any]) =
  #externalMacro(module: "NetworkingMacros", type: "InterceptorsMacro")

/// Generates cache configuration for API protocols.
///
/// Applies caching configuration to protocol-level definitions, generating
/// a static `cacheConfiguration` property that can be used by the client implementation.
///
/// Example:
/// ```swift
/// @Cacheable(duration: 300)
/// protocol UserAPI {
///   func getUser(id: String) async throws -> User
/// }
/// ```
///
/// The generated extension provides cache configuration:
/// ```swift
/// extension UserAPI {
///   static var cacheConfiguration: CacheConfiguration {
///     CacheConfiguration(
///       duration: .ttl(300),
///       policy: .standard
///     )
///   }
/// }
/// ```
///
/// - Parameters:
///   - duration: Cache duration in seconds
///   - policy: Caching policy strategy (default: .standard)
///
/// - Note: This macro can only be applied to protocol declarations.
@attached(peer, names: arbitrary)
public macro Cacheable(
  duration: TimeInterval,
  policy: CachingPolicy = .standard
) = #externalMacro(module: "NetworkingMacros", type: "CacheableMacro")

/// Generates a timing wrapper for performance measurement.
///
/// Creates a measured variant of the function that records execution duration
/// using the Metrics system. The wrapper function is named with a `_measured` suffix.
///
/// Example:
/// ```swift
/// @Measured
/// func fetchUsers() async throws -> [User] {
///   return try await api.getUsers()
/// }
/// ```
///
/// The generated wrapper function:
/// ```swift
/// func fetchUsers_measured() async throws -> [User] {
///   let startTime = Date()
///   defer {
///     let duration = Date().timeIntervalSince(startTime)
///     Metrics.shared.record(duration: duration, operation: "fetchUsers")
///   }
///   return try await fetchUsers()
/// }
/// ```
///
/// - Parameter name: Custom metric operation name (default: function name)
///
/// - Note: This macro can only be applied to function declarations.
@attached(peer, names: suffixed(_measured))
public macro Measured(
  name: String? = nil
) = #externalMacro(module: "NetworkingMacros", type: "MeasuredMacro")

// MARK: - Supporting Types for Macro-Generated Code

/// Configuration generated by @Cacheable macro
/// Uses existing CachingPolicy and CacheDuration (from NetworkClientBuilder)
public struct CacheConfiguration: Sendable {
  public let duration: CacheDuration
  public let policy: CachingPolicy

  public init(duration: CacheDuration, policy: CachingPolicy) {
    self.duration = duration
    self.policy = policy
  }
}

/// Simple metrics recorder for @Measured macro
public final class Metrics: @unchecked Sendable {
  public static let shared = Metrics()

  private init() {}

  /// Records operation duration for performance measurement
  /// - Parameters:
  ///   - duration: Time interval in seconds
  ///   - operation: Operation identifier
  public func record(duration: TimeInterval, operation: String) {
    // LIFECYCLE: Fire-and-forget metrics recording
    // In production, this would send to observability system
    #if DEBUG
      print("[\(operation)] Duration: \(duration)s")
    #endif
  }
}
