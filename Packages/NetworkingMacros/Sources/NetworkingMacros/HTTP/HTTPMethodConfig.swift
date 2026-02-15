import Foundation

/// Configuration for HTTP method macros.
///
/// Centralizes the "what varies" between HTTP method macros (GET, POST, PUT, PATCH, DELETE).
/// Each method has different requirements for request bodies and return types.
///
/// Example:
/// ```swift
/// let config = HTTPMethodConfig.post
/// // config.method = "POST"
/// // config.requiresBody = true
/// // config.allowsVoidReturn = false
/// ```
public struct HTTPMethodConfig: Sendable {
  /// The HTTP method name (e.g., "GET", "POST", "PUT", "PATCH", "DELETE").
  public let method: String

  /// Whether this HTTP method requires a request body.
  ///
  /// - `true` for POST, PUT, PATCH (body required)
  /// - `false` for GET, DELETE (body not allowed)
  public let requiresBody: Bool

  /// Whether this HTTP method allows Void return type.
  ///
  /// - `true` for DELETE (fire-and-forget allowed)
  /// - `false` for GET, POST, PUT, PATCH (must return response)
  public let allowsVoidReturn: Bool

  /// Configuration for GET requests.
  public static let get = Self(
    method: "GET",
    requiresBody: false,
    allowsVoidReturn: false
  )

  /// Configuration for POST requests.
  public static let post = Self(
    method: "POST",
    requiresBody: true,
    allowsVoidReturn: false
  )

  /// Configuration for PUT requests.
  public static let put = Self(
    method: "PUT",
    requiresBody: true,
    allowsVoidReturn: false
  )

  /// Configuration for PATCH requests.
  public static let patch = Self(
    method: "PATCH",
    requiresBody: true,
    allowsVoidReturn: false
  )

  /// Configuration for DELETE requests.
  public static let delete = Self(
    method: "DELETE",
    requiresBody: false,
    allowsVoidReturn: true
  )
}
