import Foundation

// MARK: - Given Steps for Network Testing

/// Given step that sets up the base URL for requests.
public struct GivenBaseURL: GivenStep, DescribableStep {
  private let url: URL

  public var stepDescription: String {
    "the base URL is \"\(url.absoluteString)\""
  }

  /// Creates a base URL setup step.
  ///
  /// - Parameter url: The base URL string
  public init(_ urlString: String) {
    guard let url = URL(string: urlString) else {
      preconditionFailure("Invalid URL: \(urlString)")
    }
    self.url = url
  }

  /// Creates a base URL setup step.
  ///
  /// - Parameter url: The base URL
  public init(_ url: URL) {
    self.url = url
  }

  public func setup(context: ScenarioContext) async throws {
    context[.baseURL] = url
  }
}

/// Given step that configures a mock response.
public struct GivenMockResponse: GivenStep, DescribableStep {
  private let path: String
  private let method: HTTPMethod?
  private let statusCode: Int
  private let headers: [String: String]
  private let body: Data?
  private let delay: TimeInterval?

  public var stepDescription: String {
    if let method = method {
      return "\(method.rawValue) \"\(path)\" returns \(statusCode)"
    }
    return "\"\(path)\" returns \(statusCode)"
  }

  /// Creates a mock response configuration.
  ///
  /// - Parameters:
  ///   - path: The request path to match
  ///   - method: Optional HTTP method to match
  ///   - statusCode: Response status code
  ///   - headers: Response headers
  ///   - body: Response body data
  ///   - delay: Optional response delay
  public init(
    path: String,
    method: HTTPMethod? = nil,
    statusCode: Int = 200,
    headers: [String: String] = [:],
    body: Data? = nil,
    delay: TimeInterval? = nil
  ) {
    self.path = path
    self.method = method
    self.statusCode = statusCode
    self.headers = headers
    self.body = body
    self.delay = delay
  }

  /// Creates a mock response with JSON body.
  ///
  /// - Parameters:
  ///   - path: The request path to match
  ///   - method: Optional HTTP method to match
  ///   - statusCode: Response status code
  ///   - json: Encodable JSON body
  ///   - encoder: JSON encoder
  public init<T: Encodable>(
    path: String,
    method: HTTPMethod? = nil,
    statusCode: Int = 200,
    json: T,
    encoder: JSONEncoder = JSONEncoder()
  ) throws {
    self.path = path
    self.method = method
    self.statusCode = statusCode
    self.headers = ["Content-Type": "application/json"]
    self.body = try encoder.encode(json)
    self.delay = nil
  }

  public func setup(context: ScenarioContext) async throws {
    let mockClient = context.mockClient

    var expectation = mockClient.expect(.path(path))

    if let method = method {
      expectation = mockClient.expect(.method(method))
    }

    var responseData = body ?? Data()
    var responseHeaders = headers

    if let delay = delay {
      _ = expectation.andReturn(
        .custom(statusCode: statusCode, data: responseData, headers: responseHeaders, delay: delay)
      )
    } else {
      _ = expectation.andReturn(
        .success(statusCode: statusCode, data: responseData, headers: responseHeaders)
      )
    }
  }
}

/// Given step that configures a mock error response.
public struct GivenMockError: GivenStep, DescribableStep {
  private let path: String
  private let method: HTTPMethod?
  private let error: HTTPError

  public var stepDescription: String {
    "\"\(path)\" returns error \(error.category)"
  }

  /// Creates a mock error configuration.
  ///
  /// - Parameters:
  ///   - path: The request path to match
  ///   - method: Optional HTTP method to match
  ///   - error: The error to return
  public init(
    path: String,
    method: HTTPMethod? = nil,
    error: HTTPError
  ) {
    self.path = path
    self.method = method
    self.error = error
  }

  /// Creates a mock error with category.
  ///
  /// - Parameters:
  ///   - path: The request path to match
  ///   - method: Optional HTTP method to match
  ///   - category: The error category
  public init(
    path: String,
    method: HTTPMethod? = nil,
    category: HTTPError.Category
  ) {
    self.path = path
    self.method = method
    self.error = HTTPError(category: category)
  }

  public func setup(context: ScenarioContext) async throws {
    let mockClient = context.mockClient

    var expectation = mockClient.expect(.path(path))

    if let method = method {
      expectation = mockClient.expect(.method(method))
    }

    _ = expectation.andReturn(.failure(error))
  }
}

/// Given step that sets a context value.
public struct GivenContextValue<T: Sendable>: GivenStep, DescribableStep {
  private let key: ContextKey<T>
  private let value: T

  public var stepDescription: String {
    "context \"\(key.name)\" is set"
  }

  /// Creates a context value setup step.
  ///
  /// - Parameters:
  ///   - key: The context key
  ///   - value: The value to set
  public init(_ key: ContextKey<T>, value: T) {
    self.key = key
    self.value = value
  }

  public func setup(context: ScenarioContext) async throws {
    context[key] = value
  }
}

/// Given step that sets authentication headers.
public struct GivenAuthentication: GivenStep, DescribableStep {
  private let type: AuthType

  public var stepDescription: String {
    switch type {
    case .bearer:
      return "authenticated with bearer token"
    case .basic:
      return "authenticated with basic auth"
    case .apiKey:
      return "authenticated with API key"
    }
  }

  /// Authentication type.
  public enum AuthType: Sendable {
    case bearer(String)
    case basic(username: String, password: String)
    case apiKey(header: String, value: String)
  }

  /// Creates an authentication setup step.
  ///
  /// - Parameter type: The authentication type
  public init(_ type: AuthType) {
    self.type = type
  }

  /// Creates a bearer token authentication step.
  ///
  /// - Parameter token: The bearer token
  public static func bearer(_ token: String) -> Self {
    Self(.bearer(token))
  }

  /// Creates a basic authentication step.
  ///
  /// - Parameters:
  ///   - username: The username
  ///   - password: The password
  public static func basic(username: String, password: String) -> Self {
    Self(.basic(username: username, password: password))
  }

  public func setup(context: ScenarioContext) async throws {
    switch type {
    case .bearer(let token):
      context[.authHeader] = "Bearer \(token)"
    case .basic(let username, let password):
      let credentials = "\(username):\(password)"
      let encoded = Data(credentials.utf8).base64EncodedString()
      context[.authHeader] = "Basic \(encoded)"
    case .apiKey(let header, let value):
      var existing = context[.customHeaders] ?? [:]
      existing[header] = value
      context[.customHeaders] = existing
    }
  }
}

/// Given step that configures request headers.
public struct GivenHeaders: GivenStep, DescribableStep {
  private let headers: [String: String]

  public var stepDescription: String {
    "request headers are configured"
  }

  /// Creates a headers setup step.
  ///
  /// - Parameter headers: The headers to set
  public init(_ headers: [String: String]) {
    self.headers = headers
  }

  /// Creates a headers setup step with a single header.
  ///
  /// - Parameters:
  ///   - name: Header name
  ///   - value: Header value
  public init(_ name: String, _ value: String) {
    self.headers = [name: value]
  }

  public func setup(context: ScenarioContext) async throws {
    var existing = context[.customHeaders] ?? [:]
    for (key, value) in headers {
      existing[key] = value
    }
    context[.customHeaders] = existing
  }
}

/// Given step that clears previous mock expectations.
public struct GivenCleanState: GivenStep, DescribableStep {
  public var stepDescription: String {
    "a clean test state"
  }

  public init() {}

  public func setup(context: ScenarioContext) async throws {
    context.mockClient.clearRequestHistory()
    context.lastRequest = nil
    context.lastResponse = nil
    context.lastError = nil
  }
}

// MARK: - Context Key Extensions

extension ContextKey where Value == String {
  /// Authentication header value.
  public static var authHeader: ContextKey<String> { ContextKey("authHeader") }
}

// MARK: - Convenience Functions (prefixed to avoid macro conflicts)

/// Creates a base URL Given step.
public func givenBaseURL(_ url: String) -> GivenBaseURL {
  GivenBaseURL(url)
}

/// Creates a mock response Given step.
public func givenMockResponse(
  path: String,
  method: HTTPMethod? = nil,
  status: Int = 200,
  body: Data? = nil
) -> GivenMockResponse {
  GivenMockResponse(path: path, method: method, statusCode: status, body: body)
}

/// Creates a mock JSON response Given step.
public func givenMockJSON<T: Encodable>(
  path: String,
  method: HTTPMethod? = nil,
  status: Int = 200,
  json: T
) throws -> GivenMockResponse {
  try GivenMockResponse(path: path, method: method, statusCode: status, json: json)
}

/// Creates a mock error Given step.
public func givenMockError(
  path: String,
  method: HTTPMethod? = nil,
  category: HTTPError.Category
) -> GivenMockError {
  GivenMockError(path: path, method: method, category: category)
}

/// Creates a bearer auth Given step.
public func givenBearerAuth(_ token: String) -> GivenAuthentication {
  GivenAuthentication.bearer(token)
}

/// Creates a clean state Given step.
public func givenCleanState() -> GivenCleanState {
  GivenCleanState()
}
