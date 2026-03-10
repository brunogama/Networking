import Foundation
import NetworkingCore

// MARK: - HTTP Method Phantom Types

/// Marker protocol for HTTP method phantom types.
///
/// Conform to this protocol to create custom method types for use with
/// ``TypedHTTPRequest``. The framework provides standard conformances
/// for all common HTTP methods.
public protocol HTTPMethodType: Sendable {
  /// The raw HTTP method string (e.g. "GET", "POST").
  static var method: HTTPMethod { get }
}

/// Phantom type representing the GET HTTP method.
public enum GETMethod: HTTPMethodType {
  public static let method: HTTPMethod = .get
}

/// Phantom type representing the POST HTTP method.
public enum POSTMethod: HTTPMethodType {
  public static let method: HTTPMethod = .post
}

/// Phantom type representing the PUT HTTP method.
public enum PUTMethod: HTTPMethodType {
  public static let method: HTTPMethod = .put
}

/// Phantom type representing the DELETE HTTP method.
public enum DELETEMethod: HTTPMethodType {
  public static let method: HTTPMethod = .delete
}

/// Phantom type representing the PATCH HTTP method.
public enum PATCHMethod: HTTPMethodType {
  public static let method: HTTPMethod = .patch
}

/// Phantom type representing the HEAD HTTP method.
public enum HEADMethod: HTTPMethodType {
  public static let method: HTTPMethod = .head
}

// MARK: - HTTP Environment Phantom Types

/// Marker protocol for HTTP environment phantom types.
///
/// Conform to this protocol to define custom deployment environments
/// for compile-time environment validation with ``TypedHTTPRequest``.
public protocol HTTPEnvironmentType: Sendable {
  /// The base URL for this environment.
  static var baseURL: URL { get }

  /// A human-readable name for this environment.
  static var name: String { get }
}

/// Phantom type representing a production environment.
public enum ProductionEnvironment: HTTPEnvironmentType {
  public static let baseURL = URL(string: "https://api.example.com")!
  public static let name = "production"
}

/// Phantom type representing a staging environment.
public enum StagingEnvironment: HTTPEnvironmentType {
  public static let baseURL = URL(string: "https://staging-api.example.com")!
  public static let name = "staging"
}

/// Phantom type representing a development environment.
public enum DevelopmentEnvironment: HTTPEnvironmentType {
  public static let baseURL = URL(string: "http://localhost:8080")!
  public static let name = "development"
}

/// A wildcard environment that can be used when the environment is not constrained.
public enum AnyEnvironment: HTTPEnvironmentType {
  public static let baseURL = URL(string: "https://localhost")!
  public static let name = "any"
}

// MARK: - Typed HTTP Request

/// An HTTP request with compile-time method and environment validation.
///
/// `TypedHTTPRequest` uses phantom types to provide compile-time guarantees
/// about request method and target environment. This prevents common mistakes
/// like accidentally sending a DELETE request to production.
///
/// ## Usage
///
/// ```swift
/// // Compile-time safe: only GET to staging
/// let request = TypedHTTPRequest<GETMethod, StagingEnvironment>(
///     path: "/api/users"
/// )
///
/// // Convert to untyped for execution
/// let httpRequest = request.toHTTPRequest()
/// let response = try await client.execute(httpRequest)
/// ```
///
/// ## Custom Environments
///
/// Define your own environment types:
///
/// ```swift
/// enum MyProductionEnv: HTTPEnvironmentType {
///     static let baseURL = URL(string: "https://api.myapp.com")!
///     static let name = "production"
/// }
///
/// let request = TypedHTTPRequest<POSTMethod, MyProductionEnv>(path: "/users")
/// ```
public struct TypedHTTPRequest<Method: HTTPMethodType, Environment: HTTPEnvironmentType>: Sendable {
  /// The request path relative to the environment's base URL.
  public let path: String

  /// HTTP headers for this request.
  public let headers: [String: String]

  /// Request body data.
  public let body: Data?

  /// Request timeout interval.
  public let timeout: TimeInterval

  /// Creates a new typed HTTP request.
  ///
  /// - Parameters:
  ///   - path: The request path relative to the environment's base URL
  ///   - headers: HTTP headers (default: empty)
  ///   - body: Request body data (default: nil)
  ///   - timeout: Timeout interval in seconds (default: 30)
  public init(
    path: String,
    headers: [String: String] = [:],
    body: Data? = nil,
    timeout: TimeInterval = 30.0
  ) {
    self.path = path
    self.headers = headers
    self.body = body
    self.timeout = timeout
  }

  /// The resolved URL combining the environment's base URL and the path.
  public var url: URL {
    let baseString = Environment.baseURL.absoluteString
    let fullString =
      baseString.hasSuffix("/")
      ? "\(baseString)\(path.hasPrefix("/") ? String(path.dropFirst()) : path)"
      : "\(baseString)\(path.hasPrefix("/") ? path : "/\(path)")"
    return URL(string: fullString) ?? Environment.baseURL
  }

  /// The HTTP method derived from the phantom type.
  public var method: HTTPMethod {
    Method.method
  }

  /// Converts this typed request to an untyped ``HTTPRequest`` for execution.
  ///
  /// - Returns: An ``HTTPRequest`` ready for execution by an ``HTTPClient``
  public func toHTTPRequest() -> HTTPRequest {
    HTTPRequest(
      method: method,
      url: url,
      headers: headers,
      body: body,
      timeout: timeout
    )
  }

  /// Creates a new request with an additional header.
  ///
  /// - Parameters:
  ///   - name: The header name
  ///   - value: The header value
  /// - Returns: A new typed request with the header added
  public func addingHeader(_ name: String, _ value: String) -> Self {
    var newHeaders = headers
    newHeaders[name] = value
    return Self(path: path, headers: newHeaders, body: body, timeout: timeout)
  }

  /// Creates a new request with the specified body.
  ///
  /// - Parameter data: The body data
  /// - Returns: A new typed request with the body set
  public func withBody(_ data: Data) -> Self {
    Self(path: path, headers: headers, body: data, timeout: timeout)
  }

  /// Creates a new request with the specified timeout.
  ///
  /// - Parameter interval: The timeout interval
  /// - Returns: A new typed request with the timeout set
  public func withTimeout(_ interval: TimeInterval) -> Self {
    Self(path: path, headers: headers, body: body, timeout: interval)
  }
}

// MARK: - Body-Allowed Method Extension

extension TypedHTTPRequest where Method: BodyAllowedMethod {
  /// Adds an encodable body to the request.
  ///
  /// This method is only available for HTTP methods that semantically support request bodies
  /// (POST, PUT, PATCH). Attempting to call this on GET, DELETE, or HEAD requests will result
  /// in a compile-time error.
  ///
  /// The value is automatically encoded to JSON, and the `Content-Type: application/json` header
  /// is set. If you need custom encoding or a different content type, use ``withBody(_:)`` directly.
  ///
  /// ## Example
  ///
  /// ```swift
  /// struct User: Encodable {
  ///     let name: String
  ///     let email: String
  /// }
  ///
  /// let request = TypedHTTPRequest<POSTMethod, ProductionEnvironment>(path: "/users")
  ///     .withJSONBody(User(name: "Alice", email: "alice@example.com"))
  ///
  /// // ❌ This will not compile (GET doesn't allow bodies):
  /// // let getRequest = TypedHTTPRequest<GETMethod, ProductionEnvironment>(path: "/users")
  /// //     .withJSONBody(someData)  // Compile error
  /// ```
  ///
  /// - Parameters:
  ///   - value: The Encodable value to serialize as JSON body
  ///   - encoder: The JSON encoder to use (default: `JSONEncoder()`)
  /// - Returns: A new typed request with the JSON body and Content-Type header set
  /// - Throws: `EncodingError` if the value cannot be encoded
  public func withJSONBody<T: Encodable & Sendable>(
    _ value: T,
    encoder: JSONEncoder = JSONEncoder()
  ) throws -> Self {
    let data = try encoder.encode(value)
    var newHeaders = headers
    newHeaders["Content-Type"] = "application/json"
    return Self(path: path, headers: newHeaders, body: data, timeout: timeout)
  }
}

// MARK: - HTTPClient Extension for Typed Requests

extension HTTPClient {
  /// Executes a typed HTTP request.
  ///
  /// - Parameter request: The typed request to execute
  /// - Returns: The HTTP response
  /// - Throws: ``HTTPError`` if the request fails
  public func execute<M: HTTPMethodType, E: HTTPEnvironmentType>(
    _ request: TypedHTTPRequest<M, E>
  ) async throws -> HTTPResponse {
    try await execute(request.toHTTPRequest())
  }
}
