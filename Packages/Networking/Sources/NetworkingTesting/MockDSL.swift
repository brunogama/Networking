import NetworkingRuntime
import NetworkingInterceptorsCompat
import NetworkingObservability
import Foundation

// MARK: - NetworkingMock DSL

/// A result-builder DSL for creating mock network expectations.
///
/// `NetworkingMock` provides a declarative syntax for defining request
/// expectations and mock responses, wrapping the existing ``MockNetworkClient``.
///
/// ## Usage
///
/// ```swift
/// let mock = try NetworkingMock {
///     Expect {
///         Method(.get)
///         Path("/users/123")
///         HeaderPresent("Authorization")
///     }
///     Respond {
///         Status(.ok)
///         JSONBody(User(id: 123, name: "Test"))
///     }
/// }
///
/// let client = mock.client
/// let response = try await client.execute(request)
/// ```
public struct NetworkingMock: Sendable {
  /// The underlying mock client.
  public let client: MockNetworkClient

  /// Creates a `NetworkingMock` from a set of mock rules.
  ///
  /// - Parameter content: A result builder closure providing mock rules
  public init(@MockRuleBuilder _ content: () throws -> [MockRule]) throws {
    let rules = try content()
    let mockClient = MockNetworkClient()

    for rule in rules {
      let expectation: MockNetworkClient.RequestExpectation

      // Build matcher from expect components
      if let path = rule.expectation.path {
        switch rule.expectation.method {
        case .some(.get):
          expectation = mockClient.expectGET(path)
        case .some(.post):
          expectation = mockClient.expectPOST(path)
        case .some(.put):
          expectation = mockClient.expectPUT(path)
        case .some(.delete):
          expectation = mockClient.expectDELETE(path)
        default:
          expectation = mockClient.expect(.path(path))
        }
      } else {
        expectation = mockClient.expect(.custom({ _ in true }))
      }

      // Apply response
      if let error = rule.response.error {
        expectation.andReturnError(error)
      } else {
        let statusCode = rule.response.statusCode ?? 200
        let data = rule.response.body ?? Data()
        var headers: [String: String] = [:]
        if rule.response.isJSON {
          headers["Content-Type"] = "application/json"
        }
        for (name, value) in rule.response.headers {
          headers[name] = value
        }

        expectation.andReturn(
          .success(statusCode: statusCode, data: data, headers: headers)
        )
      }

      // Apply count constraints
      if let count = rule.expectation.count {
        expectation.exactly(count)
      }
    }

    self.client = mockClient
  }
}

// MARK: - Mock Rule

/// A single mock rule pairing an expectation with a response.
public struct MockRule: Sendable {
  public let expectation: MockExpectation
  public let response: MockResponse
}

// MARK: - Mock Rule Builder

/// Result builder for composing mock rules.
@resultBuilder
public struct MockRuleBuilder {
  public static func buildBlock(_ components: MockRule...) -> [MockRule] {
    components
  }

  public static func buildPartialBlock(first: MockExpectation) -> MockExpectation {
    first
  }

  public static func buildPartialBlock(first: MockResponse) -> MockResponse {
    first
  }

  /// When an Expect is followed by a Respond, they form a MockRule.
  public static func buildPartialBlock(
    accumulated: MockExpectation,
    next: MockResponse
  ) -> MockRule {
    MockRule(expectation: accumulated, response: next)
  }

  public static func buildPartialBlock(accumulated: [MockRule], next: MockRule) -> [MockRule] {
    accumulated + [next]
  }

  public static func buildPartialBlock(first: MockRule) -> [MockRule] {
    [first]
  }

  public static func buildFinalResult(_ component: MockRule) -> [MockRule] {
    [component]
  }

  public static func buildFinalResult(_ component: [MockRule]) -> [MockRule] {
    component
  }
}

// MARK: - Mock Expectation (Expect block)

/// Defines what requests should match this mock rule.
public struct MockExpectation: Sendable {
  public let method: HTTPMethod?
  public let path: String?
  public let requiredHeaders: [String]
  public let headerValues: [String: String]
  public let count: Int?

  public init(
    method: HTTPMethod? = nil,
    path: String? = nil,
    requiredHeaders: [String] = [],
    headerValues: [String: String] = [:],
    count: Int? = nil
  ) {
    self.method = method
    self.path = path
    self.requiredHeaders = requiredHeaders
    self.headerValues = headerValues
    self.count = count
  }
}

// MARK: - Mock Response (Respond block)

/// Defines how the mock should respond.
public struct MockResponse: Sendable {
  public let statusCode: Int?
  public let body: Data?
  public let headers: [String: String]
  public let error: (any Error)?
  public let isJSON: Bool

  public init(
    statusCode: Int? = 200,
    body: Data? = nil,
    headers: [String: String] = [:],
    error: (any Error)? = nil,
    isJSON: Bool = false
  ) {
    self.statusCode = statusCode
    self.body = body
    self.headers = headers
    self.error = error
    self.isJSON = isJSON
  }
}

// MARK: - Expect Builder

/// Result builder for composing expectation components.
@resultBuilder
public struct ExpectBuilder {
  public static func buildBlock(_ components: ExpectComponent...) -> MockExpectation {
    var method: HTTPMethod?
    var path: String?
    var requiredHeaders: [String] = []
    var headerValues: [String: String] = [:]
    var count: Int?

    for component in components {
      switch component {
      case .method(let m):
        method = m
      case .path(let p):
        path = p
      case .headerPresent(let name):
        requiredHeaders.append(name)
      case .headerValue(let name, let value):
        headerValues[name] = value
      case .count(let c):
        count = c
      }
    }

    return MockExpectation(
      method: method,
      path: path,
      requiredHeaders: requiredHeaders,
      headerValues: headerValues,
      count: count
    )
  }
}

/// Components for building expectations.
public enum ExpectComponent: Sendable {
  case method(HTTPMethod)
  case path(String)
  case headerPresent(String)
  case headerValue(String, String)
  case count(Int)
}

// MARK: - Respond Builder

/// Result builder for composing response components.
@resultBuilder
public struct RespondBuilder {
  public static func buildBlock(_ components: RespondComponent...) -> MockResponse {
    var statusCode: Int?
    var body: Data?
    var headers: [String: String] = [:]
    var error: (any Error)?
    var isJSON = false

    for component in components {
      switch component {
      case .status(let code):
        statusCode = code
      case .body(let data):
        body = data
      case .jsonBody(let data):
        body = data
        isJSON = true
      case .header(let name, let value):
        headers[name] = value
      case .error(let err):
        error = err
      }
    }

    return MockResponse(
      statusCode: statusCode,
      body: body,
      headers: headers,
      error: error,
      isJSON: isJSON
    )
  }
}

/// Components for building responses.
///
/// - Note: `@unchecked Sendable` justification:
///   The `.error` case contains `any Error` which is not `Sendable` by default.
///   This is safe because errors are only used during test setup (single-threaded)
///   and consumed synchronously during mock response generation.
public enum RespondComponent: @unchecked Sendable {
  case status(Int)
  case body(Data)
  case jsonBody(Data)
  case header(String, String)
  case error(any Error)
}

// MARK: - DSL Functions

/// Creates an expectation block for a mock rule.
///
/// ```swift
/// Expect {
///     Method(.get)
///     Path("/users/123")
///     HeaderPresent("Authorization")
/// }
/// ```
public func Expect(@ExpectBuilder _ content: () -> MockExpectation) -> MockExpectation {
  content()
}

/// Creates a response block for a mock rule.
///
/// ```swift
/// Respond {
///     Status(.ok)
///     JSONBody(User(id: 123, name: "Test"))
/// }
/// ```
public func Respond(@RespondBuilder _ content: () throws -> MockResponse) rethrows -> MockResponse {
  try content()
}

// MARK: - DSL Component Helpers

/// Matches a specific HTTP method.
public func Method(_ method: HTTPMethod) -> ExpectComponent {
  .method(method)
}

/// Matches a specific URL path.
public func Path(_ path: String) -> ExpectComponent {
  .path(path)
}

/// Requires a header to be present (any value).
public func HeaderPresent(_ name: String) -> ExpectComponent {
  .headerPresent(name)
}

/// Requires a header with a specific value.
public func HeaderValue(_ name: String, _ value: String) -> ExpectComponent {
  .headerValue(name, value)
}

/// Sets the expected call count.
public func Count(_ count: Int) -> ExpectComponent {
  .count(count)
}

// MARK: - Response DSL Helpers

/// Defines an HTTP status for the mock response.
public func Status(_ status: HTTPStatus) -> RespondComponent {
  .status(status.rawValue)
}

/// Sets a raw data body on the mock response.
public func Body(_ data: Data) -> RespondComponent {
  .body(data)
}

/// Sets a JSON-encoded body on the mock response.
public func MockJSONBody<T: Encodable>(
  _ value: T,
  encoder: JSONEncoder = JSONEncoder()
) throws
  -> RespondComponent
{
  let data = try encoder.encode(value)
  return .jsonBody(data)
}

/// Sets a response header.
public func ResponseHeader(_ name: String, _ value: String) -> RespondComponent {
  .header(name, value)
}
