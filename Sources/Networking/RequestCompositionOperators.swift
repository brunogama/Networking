import Foundation

// MARK: - Request Modifier

/// A modifier that can be applied to an ``HTTPRequest`` to produce a new request
/// with updated properties.
///
/// ## Usage
///
/// Use modifiers with the `+` operator:
///
/// ```swift
/// let base = HTTPRequest(method: .get, url: URL(string: "https://api.example.com/users")!)
/// let authed = base + .bearerAuth("my-token")
/// let final = authed + .timeout(15) + .header("Accept", "application/json")
/// ```
public enum RequestModifier: Sendable {
  /// Adds a bearer authentication header.
  case bearerAuth(String)

  /// Adds a basic authentication header.
  case basicAuth(username: String, password: String)

  /// Adds a custom header.
  case header(String, String)

  /// Sets the request timeout.
  case timeout(TimeInterval)

  /// Sets the request body data.
  case body(Data)

  /// Sets a JSON-encodable body.
  case jsonBody(Data)

  /// Adds a query parameter to the URL.
  case queryParam(String, String)

  /// Applies this modifier to an ``HTTPRequest``, producing a new request.
  ///
  /// - Parameter request: The request to modify
  /// - Returns: A new request with the modification applied
  public func apply(to request: HTTPRequest) -> HTTPRequest {
    var newHeaders = request.headers
    var newBody = request.body
    var newTimeout = request.timeout
    var newURL = request.url

    switch self {
    case .bearerAuth(let token):
      newHeaders["Authorization"] = "Bearer \(token)"

    case .basicAuth(let username, let password):
      let credentials = "\(username):\(password)"
      if let data = credentials.data(using: .utf8) {
        let base64 = data.base64EncodedString()
        newHeaders["Authorization"] = "Basic \(base64)"
      }

    case .header(let name, let value):
      newHeaders[name] = value

    case .timeout(let interval):
      newTimeout = interval

    case .body(let data):
      newBody = data

    case .jsonBody(let data):
      newBody = data
      newHeaders["Content-Type"] = "application/json"

    case .queryParam(let name, let value):
      if var components = URLComponents(url: request.url, resolvingAgainstBaseURL: false) {
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: name, value: value))
        components.queryItems = queryItems
        if let url = components.url {
          newURL = url
        }
      }
    }

    return HTTPRequest(
      method: request.method,
      url: newURL,
      headers: newHeaders,
      body: newBody,
      timeout: newTimeout
    )
  }
}

// MARK: - Operator Overloads

/// Composes an ``HTTPRequest`` with a ``RequestModifier`` to produce a new request.
///
/// ```swift
/// let request = baseRequest + .bearerAuth(token)
/// ```
///
/// - Parameters:
///   - lhs: The base request
///   - rhs: The modifier to apply
/// - Returns: A new request with the modifier applied
public func + (lhs: HTTPRequest, rhs: RequestModifier) -> HTTPRequest {
  rhs.apply(to: lhs)
}

/// Composes two ``HTTPRequest`` instances by merging headers and properties.
///
/// The right-hand request's properties take precedence. The method and URL
/// come from the left-hand request.
///
/// ```swift
/// let merged = baseRequest + additionalHeaders
/// ```
///
/// - Parameters:
///   - lhs: The base request
///   - rhs: The request whose headers and properties to merge
/// - Returns: A new merged request
public func + (lhs: HTTPRequest, rhs: HTTPRequest) -> HTTPRequest {
  var mergedHeaders = lhs.headers
  for (key, value) in rhs.headers {
    mergedHeaders[key] = value
  }

  return HTTPRequest(
    method: lhs.method,
    url: lhs.url,
    headers: mergedHeaders,
    body: rhs.body ?? lhs.body,
    timeout: rhs.timeout
  )
}

// MARK: - Convenience Factory Methods

extension RequestModifier {
  /// Creates a JSON body modifier from an `Encodable` value.
  ///
  /// - Parameters:
  ///   - value: The value to encode as JSON
  ///   - encoder: The JSON encoder to use (defaults to `JSONEncoder()`)
  /// - Returns: A `.jsonBody` modifier, or `.body(Data())` if encoding fails
  public static func json<T: Encodable>(
    _ value: T,
    encoder: JSONEncoder = JSONEncoder()
  ) -> RequestModifier {
    guard let data = try? encoder.encode(value) else {
      return .body(Data())
    }
    return .jsonBody(data)
  }
}
