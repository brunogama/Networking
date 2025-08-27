import Foundation

// MARK: - API Generation Macros

/// Generates an HTTP API client implementation for a protocol.
///
/// Usage:
/// ```swift
/// @API(baseURL: "https://api.example.com")
/// protocol UserAPI {
///     @GET("/users/{id}")
///     func getUser(@Path id: String) async throws -> User
///
///     @POST("/users")
///     func createUser(@Body user: User) async throws -> User
/// }
/// ```
@attached(extension)
public macro API(baseURL: String) =
  #externalMacro(module: "ModernNetworkingMacros", type: "APIMacro")

// MARK: - HTTP Method Macros

/// Marks a method as a GET request.
@attached(peer)
public macro GET(_ path: String) =
  #externalMacro(module: "ModernNetworkingMacros", type: "GETMacro")

/// Marks a method as a POST request.
@attached(peer)
public macro POST(_ path: String) =
  #externalMacro(module: "ModernNetworkingMacros", type: "POSTMacro")

/// Marks a method as a PUT request.
@attached(peer)
public macro PUT(_ path: String) =
  #externalMacro(module: "ModernNetworkingMacros", type: "PUTMacro")

/// Marks a method as a DELETE request.
@attached(peer)
public macro DELETE(_ path: String) =
  #externalMacro(module: "ModernNetworkingMacros", type: "DELETEMacro")

// MARK: - Parameter Macros

/// Marks a parameter as a path parameter that will be substituted in the URL.
@attached(peer)
public macro Path(_ name: String? = nil) =
  #externalMacro(module: "ModernNetworkingMacros", type: "PathMacro")

/// Marks a parameter as the request body.
@attached(peer)
public macro Body() = #externalMacro(module: "ModernNetworkingMacros", type: "BodyMacro")

/// Marks a parameter as a query parameter.
@attached(peer)
public macro Query(_ name: String? = nil) =
  #externalMacro(module: "ModernNetworkingMacros", type: "QueryMacro")

/// Marks a parameter as a header value.
@attached(peer)
public macro Header(_ name: String) =
  #externalMacro(module: "ModernNetworkingMacros", type: "HeaderMacro")

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
  #externalMacro(module: "ModernNetworkingMacros", type: "CacheableMacro")

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
  #externalMacro(module: "ModernNetworkingMacros", type: "CacheInvalidationMacro")
