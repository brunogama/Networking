import Foundation
import NetworkingCore

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
  case bearerAuth(BearerTokenValue)

  /// Adds a basic authentication header.
  case basicAuth(username: BasicAuthUsername, password: BasicAuthPassword)

  /// Adds a custom header.
  case header(HTTPHeaderName, HTTPHeaderValue)

  /// Sets the request timeout.
  case timeout(NetworkingCore.RequestTimeout)

  /// Sets the request body data.
  case body(HTTPBody)

  /// Sets a JSON-encodable body.
  case jsonBody(HTTPBody)

  /// Adds a query parameter to the URL.
  case queryParam(QueryParameterName, QueryParameterValue)

  /// Applies this modifier to an ``HTTPRequest``, producing a new request.
  ///
  /// - Parameter request: The request to modify
  /// - Returns: A new request with the modification applied
  public func apply(to request: HTTPRequest) -> HTTPRequest {
    var headers = request.headers
    applyToHeaders(&headers)

    return HTTPRequest(
      method: request.method,
      url: updatedURL(from: request.url),
      headers: headers,
      body: updatedBody(from: request.body),
      timeout: updatedTimeout(from: request.timeout),
      id: request.id
    )
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func applyToHeaders(_ headers: inout HTTPHeaders) {
    switch self {
    case .bearerAuth(let token):
      headers["Authorization"] = "Bearer \(token)"
    case .basicAuth(let username, let password):
      if let value = basicAuthHeaderValue(username: username, password: password) {
        headers["Authorization"] = value
      }
    case .header(let name, let value):
      headers[name] = value
    case .jsonBody:
      headers["Content-Type"] = "application/json"
    case .queryParam, .timeout, .body:
      break
    }
  }

  private func updatedBody(from body: HTTPBody?) -> HTTPBody? {
    switch self {
    case .body(let data), .jsonBody(let data):
      return data
    default:
      return body
    }
  }

  private func updatedURL(from url: HTTPRequestURL) -> HTTPRequestURL {
    switch self {
    case .queryParam(let name, let value):
      return queryParameterURL(from: url, name: name, value: value)
    default:
      return url
    }
  }

  private func updatedTimeout(
    from timeout: NetworkingCore.RequestTimeout
  ) -> NetworkingCore.RequestTimeout {
    if case .timeout(let interval) = self {
      return interval
    }

    return timeout
  }

  private func basicAuthHeaderValue(
    username: BasicAuthUsername,
    password: BasicAuthPassword
  ) -> HTTPHeaderValue? {
    let credentials = "\(username):\(password)"
    guard let data = credentials.data(using: .utf8) else {
      return nil
    }
    return HTTPHeaderValue("Basic \(data.base64EncodedString())")
  }

  private func queryParameterURL(
    from url: HTTPRequestURL,
    name: QueryParameterName,
    value: QueryParameterValue
  ) -> HTTPRequestURL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return url
    }

    var queryItems = components.queryItems ?? []
    queryItems.append(URLQueryItem(name: name.rawValue, value: value.rawValue))
    components.queryItems = queryItems
    return components.url.map { HTTPRequestURL($0) } ?? url
  }
}

// MARK: - Operator Overloads

// swiftlint:disable static_operator
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
// swiftlint:enable static_operator

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
      return .body(HTTPBody(Data()))
    }
    return .jsonBody(HTTPBody(data))
  }
}
