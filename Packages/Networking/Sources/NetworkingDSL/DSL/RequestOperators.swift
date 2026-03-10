import Foundation
import NetworkingCore

// MARK: - HTTPRequest Composition

extension HTTPRequest {
  /// Composes two HTTP requests into a single request using merge semantics.
  ///
  /// This operator enables fluent request building by combining a base request with
  /// overrides. The right-hand side (rhs) takes precedence for all fields except URL,
  /// which has special handling for relative path composition.
  ///
  /// ## Merge Rules
  ///
  /// - **Method**: `rhs` method is used
  /// - **URL**: If `rhs.url` has no host, it's treated as a relative path and appended
  ///   to `lhs.url`. Otherwise, `rhs.url` completely replaces `lhs.url`.
  /// - **Headers**: Dictionaries are merged. On conflicts, `rhs` values win.
  /// - **Body**: `rhs.body` if present, otherwise `lhs.body`
  /// - **Timeout**: `rhs.timeout` is used
  ///
  /// ## Examples
  ///
  /// ```swift
  /// // Base configuration
  /// let base = HTTPRequest(
  ///     method: .get,
  ///     url: URL(string: "https://api.example.com")!,
  ///     headers: ["Accept": "application/json"]
  /// )
  ///
  /// // Override with relative path
  /// let request = base + HTTPRequest(
  ///     method: .get,
  ///     url: URL(string: "/users/1")!,
  ///     headers: ["Authorization": "Bearer token"]
  /// )
  /// // Result: GET https://api.example.com/users/1
  /// // Headers: ["Accept": "application/json", "Authorization": "Bearer token"]
  ///
  /// // Override with absolute URL
  /// let override = base + HTTPRequest(
  ///     method: .post,
  ///     url: URL(string: "https://other-api.com/data")!
  /// )
  /// // Result: POST https://other-api.com/data (lhs URL completely replaced)
  /// ```
  ///
  /// - Parameters:
  ///   - lhs: The base request providing defaults
  ///   - rhs: The override request with precedence
  /// - Returns: A new request with combined properties
  public static func + (lhs: HTTPRequest, rhs: HTTPRequest) -> HTTPRequest {
    // Determine final URL: if rhs has no host, combine paths
    let finalURL: HTTPRequestURL
    if rhs.url.host == nil {
      // Relative path: append rhs path to lhs base
      let lhsString = lhs.url.absoluteString
      let rhsPath = rhs.url.path.isEmpty ? rhs.url.absoluteString : rhs.url.path
      let separator = lhsString.hasSuffix("/") || rhsPath.hasPrefix("/") ? "" : "/"
      let trimmedLhs = lhsString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let trimmedRhs = rhsPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let combined = "\(trimmedLhs)\(separator)\(trimmedRhs)"
      finalURL = URL(string: combined).map { HTTPRequestURL($0) } ?? rhs.url
    } else {
      // Absolute URL: rhs wins completely
      finalURL = rhs.url
    }

    // Merge headers: rhs takes precedence
    var mergedHeaders = lhs.headers
    for (key, value) in rhs.headers {
      mergedHeaders[key] = value
    }

    // Body: rhs if present, otherwise lhs
    let finalBody = rhs.body ?? lhs.body

    return HTTPRequest(
      method: rhs.method,
      url: finalURL,
      headers: mergedHeaders,
      body: finalBody,
      timeout: rhs.timeout
    )
  }

  /// Composes this request with another using merge semantics.
  ///
  /// This method is a named alternative to the `+` operator, providing the same
  /// composition behavior with explicit method syntax.
  ///
  /// - Parameter other: The request to merge with this one
  /// - Returns: A new request with combined properties
  /// - SeeAlso: ``+(_:_:)`` for detailed merge semantics
  public func merged(with other: HTTPRequest) -> HTTPRequest {
    // Determine final URL: if other has no host, combine paths
    let finalURL: HTTPRequestURL
    if other.url.host == nil {
      // Relative path: append other path to self base
      let lhsString = self.url.absoluteString
      let rhsPath = other.url.path.isEmpty ? other.url.absoluteString : other.url.path
      let separator = lhsString.hasSuffix("/") || rhsPath.hasPrefix("/") ? "" : "/"
      let trimmedLhs = lhsString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let trimmedRhs = rhsPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      let combined = "\(trimmedLhs)\(separator)\(trimmedRhs)"
      finalURL = URL(string: combined).map { HTTPRequestURL($0) } ?? other.url
    } else {
      // Absolute URL: other wins completely
      finalURL = other.url
    }

    // Merge headers: other takes precedence
    var mergedHeaders = self.headers
    for (key, value) in other.headers {
      mergedHeaders[key] = value
    }

    // Body: other if present, otherwise self
    let finalBody = other.body ?? self.body

    return HTTPRequest(
      method: other.method,
      url: finalURL,
      headers: mergedHeaders,
      body: finalBody,
      timeout: other.timeout
    )
  }
}
