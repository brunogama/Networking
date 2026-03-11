import NetworkingRuntime
import NetworkingTesting
import Foundation

// swiftlint:disable file_length

// MARK: - Given Steps for Network Testing

/// Given step that sets up the base URL for requests.
public struct GivenBaseURL: GivenStep, DescribableStep {
  private let url: HTTPRequestURL

  public var stepDescription: BDDStepText {
    "the base URL is \"\(url.absoluteString)\""
  }

  /// Creates a base URL setup step.
  ///
  /// - Parameter url: The base URL
  public init(_ url: HTTPRequestURL) {
    self.url = url
  }

  public func setup(context: ScenarioContext) async throws {
    context[ContextKey<HTTPRequestURL>.baseURL] = url
  }
}

/// Given step that configures a mock response.
public struct GivenMockResponse: GivenStep, DescribableStep {
  private let path: MockRequestPath
  private let method: HTTPMethod?
  private let statusCode: HTTPStatusCode
  private let headers: HTTPHeaders
  private let body: HTTPBody?
  private let delay: RetryDelay?

  public var stepDescription: BDDStepText {
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
    path: MockRequestPath,
    method: HTTPMethod? = nil,
    statusCode: HTTPStatusCode = 200,
    headers: HTTPHeaders = [:],
    body: HTTPBody? = nil,
    delay: RetryDelay? = nil
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
    path: MockRequestPath,
    method: HTTPMethod? = nil,
    statusCode: HTTPStatusCode = 200,
    json: T,
    encoder: JSONEncoder = JSONEncoder()
  ) throws {
    self.path = path
    self.method = method
    self.statusCode = statusCode
    self.headers = ["Content-Type": "application/json"]
    self.body = HTTPBody(try encoder.encode(json))
    self.delay = nil
  }

  public func setup(context: ScenarioContext) async throws {
    let mockClient = context.mockClient

    var expectation = mockClient.expect(.path(path))

    if let method = method {
      expectation = mockClient.expect(.method(method))
    }

    let responseData = body ?? HTTPBody(Data())
    let responseHeaders = headers

    if let delay = delay {
      _ = expectation.andReturn(
        MockNetworkClient.MockResponse.custom(
          statusCode: statusCode,
          data: responseData,
          headers: responseHeaders,
          delay: MockResponseDelay(delay.rawValue)
        )
      )
    } else {
      _ = expectation.andReturn(
        MockNetworkClient.MockResponse.success(
          statusCode: statusCode,
          data: responseData,
          headers: responseHeaders
        )
      )
    }
  }
}

/// Given step that configures a mock error response.
public struct GivenMockError: GivenStep, DescribableStep {
  private let path: MockRequestPath
  private let method: HTTPMethod?
  private let error: HTTPError

  public var stepDescription: BDDStepText {
    "\"\(path)\" returns error \(error.category)"
  }

  /// Creates a mock error configuration.
  ///
  /// - Parameters:
  ///   - path: The request path to match
  ///   - method: Optional HTTP method to match
  ///   - error: The error to return
  public init(
    path: MockRequestPath,
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
    path: MockRequestPath,
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

    _ = expectation.andReturn(MockNetworkClient.MockResponse.failure(error))
  }
}

/// Given step that sets a context value.
public struct GivenContextValue<T: Sendable>: GivenStep, DescribableStep {
  private let key: ContextKey<T>
  private let value: T

  public var stepDescription: BDDStepText {
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

  public var stepDescription: BDDStepText {
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
    case bearer(BearerTokenValue)
    case basic(username: BasicAuthUsername, password: BasicAuthPassword)
    case apiKey(header: HTTPHeaderName, value: HTTPHeaderValue)
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
  public static func bearer(_ token: BearerTokenValue) -> Self {
    Self(.bearer(token))
  }

  /// Creates a basic authentication step.
  ///
  /// - Parameters:
  ///   - username: The username
  ///   - password: The password
  public static func basic(username: BasicAuthUsername, password: BasicAuthPassword) -> Self {
    Self(.basic(username: username, password: password))
  }

  public func setup(context: ScenarioContext) async throws {
    switch type {
    case .bearer(let token):
      context[.authHeader] = HTTPHeaderValue("Bearer \(token.rawValue)")
    case .basic(let username, let password):
      let credentials = "\(username.rawValue):\(password.rawValue)"
      let encoded = Data(credentials.utf8).base64EncodedString()
      context[.authHeader] = HTTPHeaderValue("Basic \(encoded)")
    case .apiKey(let header, let value):
      var existing = context[.customHeaders] ?? HTTPHeaders()
      existing[header] = value
      context[.customHeaders] = existing
    }
  }
}

/// Given step that configures request headers.
public struct GivenHeaders: GivenStep, DescribableStep {
  private let headers: HTTPHeaders

  public var stepDescription: BDDStepText {
    "request headers are configured"
  }

  /// Creates a headers setup step.
  ///
  /// - Parameter headers: The headers to set
  public init(_ headers: HTTPHeaders) {
    self.headers = headers
  }

  /// Creates a headers setup step with a single header.
  ///
  /// - Parameters:
  ///   - name: Header name
  ///   - value: Header value
  public init(_ name: HTTPHeaderName, _ value: HTTPHeaderValue) {
    self.headers = [name: value]
  }

  public func setup(context: ScenarioContext) async throws {
    var existing = context[.customHeaders] ?? HTTPHeaders()
    for (key, value) in headers {
      existing[key] = value
    }
    context[.customHeaders] = existing
  }
}

/// Given step that clears previous mock expectations.
public struct GivenCleanState: GivenStep, DescribableStep {
  public var stepDescription: BDDStepText {
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

// MARK: - Convenience Functions (prefixed to avoid macro conflicts)

/// Creates a base URL Given step.
public func givenBaseURL(_ url: HTTPRequestURL) -> GivenBaseURL {
  GivenBaseURL(url)
}

/// Creates a mock response Given step.
public func givenMockResponse(
  path: MockRequestPath,
  method: HTTPMethod? = nil,
  status: HTTPStatusCode = 200,
  body: HTTPBody? = nil
) -> GivenMockResponse {
  GivenMockResponse(path: path, method: method, statusCode: status, body: body)
}

/// Creates a mock JSON response Given step.
public func givenMockJSON<T: Encodable>(
  path: MockRequestPath,
  method: HTTPMethod? = nil,
  status: HTTPStatusCode = 200,
  json: T
) throws -> GivenMockResponse {
  try GivenMockResponse(path: path, method: method, statusCode: status, json: json)
}

/// Creates a mock error Given step.
public func givenMockError(
  path: MockRequestPath,
  method: HTTPMethod? = nil,
  category: HTTPError.Category
) -> GivenMockError {
  GivenMockError(path: path, method: method, category: category)
}

/// Creates a bearer auth Given step.
public func givenBearerAuth(_ token: BearerTokenValue) -> GivenAuthentication {
  GivenAuthentication.bearer(token)
}

/// Creates a clean state Given step.
public func givenCleanState() -> GivenCleanState {
  GivenCleanState()
}
// swiftlint:enable file_length
