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
  public let methodName: HTTPMethodName

  /// Whether this HTTP method requires a request body.
  ///
  /// - `true` for POST, PUT, PATCH (body required)
  /// - `false` for GET, DELETE (body not allowed)
  public let requestBodyRequired: RequestBodyRequiredFlag

  /// Whether this HTTP method allows Void return type.
  ///
  /// - `true` for DELETE (fire-and-forget allowed)
  /// - `false` for GET, POST, PUT, PATCH (must return response)
  public let voidReturnAllowed: VoidReturnAllowedFlag

  package var method: String {
    methodName.rawValue
  }

  package var requiresBody: Bool {
    requestBodyRequired.rawValue
  }

  package var allowsVoidReturn: Bool {
    voidReturnAllowed.rawValue
  }

  /// Configuration for GET requests.
  public static let get = Self(
    methodName: .named("GET"),
    requestBodyRequired: .notRequired,
    voidReturnAllowed: .disallowed
  )

  /// Configuration for POST requests.
  public static let post = Self(
    methodName: .named("POST"),
    requestBodyRequired: .required,
    voidReturnAllowed: .disallowed
  )

  /// Configuration for PUT requests.
  public static let put = Self(
    methodName: .named("PUT"),
    requestBodyRequired: .required,
    voidReturnAllowed: .disallowed
  )

  /// Configuration for PATCH requests.
  public static let patch = Self(
    methodName: .named("PATCH"),
    requestBodyRequired: .required,
    voidReturnAllowed: .disallowed
  )

  /// Configuration for DELETE requests.
  public static let delete = Self(
    methodName: .named("DELETE"),
    requestBodyRequired: .notRequired,
    voidReturnAllowed: .allowed
  )
}
