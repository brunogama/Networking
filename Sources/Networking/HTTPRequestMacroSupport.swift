import Foundation

// MARK: - HTTPRequest Macro Support Extensions

/// Extensions to HTTPRequest to support macro-generated code.
/// These provide a mutable builder-style API for use in generated code only.
extension HTTPRequest {
  /// Creates an HTTPRequest with a relative path for macro-generated code.
  ///
  /// This initializer is designed for use by Swift macros and should not be used directly.
  /// The baseURL should be provided by the API implementation struct.
  ///
  /// - Parameters:
  ///   - method: The HTTP method
  ///   - path: The relative path (will be combined with baseURL from context)
  ///   - baseURL: The base URL to combine with the path (defaults to empty for testing)
  ///
  /// - Note: This is a convenience for macro-generated code. Direct usage should prefer
  ///         the standard initializer with a full URL.
  public init(method: HTTPMethod, path: String, baseURL: String = "") {
    // Combine baseURL and path
    let urlString = baseURL.isEmpty ? path : "\(baseURL)\(path)"
    guard let url = URL(string: urlString) else {
      // If URL construction fails, use a placeholder URL
      // In production, this should be caught by validation
      let fallbackURL = URL(string: "http://invalid.url")!
      self.init(method: method, url: fallbackURL, headers: [:], body: nil, timeout: 30.0)
      return
    }

    self.init(method: method, url: url, headers: [:], body: nil, timeout: 30.0)
  }

  /// Adds a query parameter to the request.
  ///
  /// Creates a new HTTPRequest with the query parameter added to the URL.
  /// This is a mutating-style method for use in macro-generated code.
  ///
  /// - Parameters:
  ///   - name: The query parameter name
  ///   - value: The query parameter value (will be converted to String)
  ///
  /// - Note: This creates a new HTTPRequest instance with the updated URL.
  public mutating func addQueryParameter<T>(name: String, value: T) {
    guard var components = URLComponents(url: self.url, resolvingAgainstBaseURL: false) else {
      return
    }

    var queryItems = components.queryItems ?? []
    queryItems.append(URLQueryItem(name: name, value: "\(value)"))
    components.queryItems = queryItems

    guard let newURL = components.url else {
      return
    }

    self = HTTPRequest(
      method: self.method,
      url: newURL,
      headers: self.headers,
      body: self.body,
      timeout: self.timeout
    )
  }

  /// Sets the request body.
  ///
  /// Creates a new HTTPRequest with the specified body data.
  ///
  /// - Parameter data: The body data to set
  ///
  /// - Note: This creates a new HTTPRequest instance with the updated body.
  public mutating func setBody(_ data: Data) {
    self = HTTPRequest(
      method: self.method,
      url: self.url,
      headers: self.headers,
      body: data,
      timeout: self.timeout
    )
  }

  /// Adds a header to the request.
  ///
  /// Creates a new HTTPRequest with the header added to the headers dictionary.
  ///
  /// - Parameters:
  ///   - name: The header name
  ///   - value: The header value
  ///
  /// - Note: This creates a new HTTPRequest instance with the updated headers.
  public mutating func addHeader(name: String, value: String) {
    var newHeaders = self.headers
    newHeaders[name] = value

    self = HTTPRequest(
      method: self.method,
      url: self.url,
      headers: newHeaders,
      body: self.body,
      timeout: self.timeout
    )
  }

  /// Sets multiple headers at once.
  ///
  /// Creates a new HTTPRequest with the specified headers merged into existing headers.
  ///
  /// - Parameter headers: Dictionary of headers to add
  ///
  /// - Note: New headers will override existing headers with the same name.
  public mutating func setHeaders(_ headers: [String: String]) {
    var newHeaders = self.headers
    for (key, value) in headers {
      newHeaders[key] = value
    }

    self = HTTPRequest(
      method: self.method,
      url: self.url,
      headers: newHeaders,
      body: self.body,
      timeout: self.timeout
    )
  }
}
