import NetworkingRuntime
import NetworkingInterceptorsCompat
import NetworkingObservability
import Foundation

// swiftlint:disable file_length

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
      let expectation = Self.makeExpectation(for: rule.expectation, using: mockClient)
      Self.applyResponse(rule.response, to: expectation)
      Self.applyCount(rule.expectation.count, to: expectation)
    }

    self.client = mockClient
  }

  private static func makeExpectation(
    for expectation: MockExpectation,
    using mockClient: MockNetworkClient
  ) -> MockNetworkClient.RequestExpectation {
    guard let path = expectation.path else {
      return mockClient.expect(.custom(MockURLRequestPredicate { _ in true }))
    }

    let builders: [HTTPMethod: (MockRequestPath) -> MockNetworkClient.RequestExpectation] = [
      .get: mockClient.expectGET,
      .post: mockClient.expectPOST,
      .put: mockClient.expectPUT,
      .delete: mockClient.expectDELETE,
    ]
    if let method = expectation.method,
      let builder = builders[method]
    {
      return builder(path)
    }
    return mockClient.expect(.path(path))
  }

  private static func applyResponse(
    _ response: MockResponse,
    to expectation: MockNetworkClient.RequestExpectation
  ) {
    if let error = response.error {
      expectation.andReturnError(error)
      return
    }

    expectation.andReturn(
      .success(
        statusCode: response.statusCode ?? 200,
        data: response.body ?? HTTPBody(Data()),
        headers: response.responseHeaders
      )
    )
  }

  private static func applyCount(
    _ count: RequestCount?,
    to expectation: MockNetworkClient.RequestExpectation
  ) {
    guard let count else {
      return
    }

    expectation.exactly(count)
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
  public let path: MockRequestPath?
  public let requiredHeaders: [HTTPHeaderName]
  public let headerValues: HTTPHeaders
  public let count: RequestCount?

  public init(
    method: HTTPMethod? = nil,
    path: MockRequestPath? = nil,
    requiredHeaders: [HTTPHeaderName] = [],
    headerValues: HTTPHeaders = [:],
    count: RequestCount? = nil
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
  public let statusCode: HTTPStatusCode?
  public let body: HTTPBody?
  public let headers: HTTPHeaders
  public let error: (any Error)?
  public let isJSON: MockJSONResponseFlag

  public init(
    statusCode: HTTPStatusCode? = 200,
    body: HTTPBody? = nil,
    headers: HTTPHeaders = [:],
    error: (any Error)? = nil,
    isJSON: MockJSONResponseFlag = false
  ) {
    self.statusCode = statusCode
    self.body = body
    self.headers = headers
    self.error = error
    self.isJSON = isJSON
  }

  fileprivate var responseHeaders: HTTPHeaders {
    var responseHeaders = headers
    if isJSON.rawValue {
      responseHeaders["Content-Type"] = "application/json"
    }
    return responseHeaders
  }
}

// MARK: - Expect Builder

/// Result builder for composing expectation components.
@resultBuilder
public struct ExpectBuilder {
  public static func buildBlock(_ components: ExpectComponent...) -> MockExpectation {
    var accumulator = ExpectationAccumulator()
    for component in components {
      accumulator.apply(component)
    }
    return accumulator.expectation
  }
}

/// Components for building expectations.
public enum ExpectComponent: Sendable {
  case method(HTTPMethod)
  case path(MockRequestPath)
  case headerPresent(HTTPHeaderName)
  case headerValue(HTTPHeaderName, HTTPHeaderValue)
  case count(RequestCount)
}

// MARK: - Respond Builder

/// Result builder for composing response components.
@resultBuilder
public struct RespondBuilder {
  public static func buildBlock(_ components: RespondComponent...) -> MockResponse {
    var accumulator = ResponseAccumulator()
    for component in components {
      accumulator.apply(component)
    }
    return accumulator.response
  }
}

/// Components for building responses.
///
/// - Note: `@unchecked Sendable` justification:
///   The `.error` case contains `any Error` which is not `Sendable` by default.
///   This is safe because errors are only used during test setup (single-threaded)
///   and consumed synchronously during mock response generation.
public enum RespondComponent: @unchecked Sendable {
  case status(HTTPStatusCode)
  case body(HTTPBody)
  case jsonBody(HTTPBody)
  case header(HTTPHeaderName, HTTPHeaderValue)
  case error(any Error)
}

private struct ExpectationAccumulator {
  var method: HTTPMethod?
  var path: MockRequestPath?
  var requiredHeaders: [HTTPHeaderName] = []
  var headerValues: HTTPHeaders = [:]
  var count: RequestCount?

  mutating func apply(_ component: ExpectComponent) {
    if applyRequestTarget(component) || applyHeader(component) {
      return
    }
    applyCount(component)
  }

  var expectation: MockExpectation {
    MockExpectation(
      method: method,
      path: path,
      requiredHeaders: requiredHeaders,
      headerValues: headerValues,
      count: count
    )
  }

  private mutating func applyRequestTarget(_ component: ExpectComponent) -> Bool {
    switch component {
    case .method(let methodValue):
      method = methodValue
      return true
    case .path(let requestPath):
      path = requestPath
      return true
    default:
      return false
    }
  }

  private mutating func applyHeader(_ component: ExpectComponent) -> Bool {
    switch component {
    case .headerPresent(let name):
      requiredHeaders.append(name)
      return true
    case .headerValue(let name, let value):
      headerValues[name] = value
      return true
    default:
      return false
    }
  }

  private mutating func applyCount(_ component: ExpectComponent) {
    if case .count(let requestCount) = component {
      count = requestCount
    }
  }
}

private struct ResponseAccumulator {
  var statusCode: HTTPStatusCode?
  var body: HTTPBody?
  var headers: HTTPHeaders = [:]
  var error: (any Error)?
  var isJSON: MockJSONResponseFlag = false

  mutating func apply(_ component: RespondComponent) {
    if applyPayload(component) || applyHeader(component) {
      return
    }
    applyError(component)
  }

  var response: MockResponse {
    MockResponse(
      statusCode: statusCode,
      body: body,
      headers: headers,
      error: error,
      isJSON: isJSON
    )
  }

  private mutating func applyPayload(_ component: RespondComponent) -> Bool {
    switch component {
    case .status(let statusCode):
      self.statusCode = statusCode
      return true
    case .body(let responseBody):
      body = responseBody
      return true
    case .jsonBody(let responseBody):
      body = responseBody
      isJSON = true
      return true
    default:
      return false
    }
  }

  private mutating func applyHeader(_ component: RespondComponent) -> Bool {
    guard case .header(let name, let value) = component else {
      return false
    }

    headers[name] = value
    return true
  }

  private mutating func applyError(_ component: RespondComponent) {
    if case .error(let responseError) = component {
      error = responseError
    }
  }
}

// MARK: - DSL Functions

// swiftlint:disable identifier_name

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
public func Path(_ path: MockRequestPath) -> ExpectComponent {
  .path(path)
}

/// Requires a header to be present (any value).
public func HeaderPresent(_ name: HTTPHeaderName) -> ExpectComponent {
  .headerPresent(name)
}

/// Requires a header with a specific value.
public func HeaderValue(_ name: HTTPHeaderName, _ value: HTTPHeaderValue) -> ExpectComponent {
  .headerValue(name, value)
}

/// Sets the expected call count.
public func Count(_ count: RequestCount) -> ExpectComponent {
  .count(count)
}

// MARK: - Response DSL Helpers

/// Defines an HTTP status for the mock response.
public func Status(_ status: HTTPStatus) -> RespondComponent {
  .status(status.rawValue)
}

/// Sets a raw data body on the mock response.
public func Body(_ data: HTTPBody) -> RespondComponent {
  .body(data)
}

package func Body(_ data: Data) -> RespondComponent {
  .body(HTTPBody(data))
}

/// Sets a JSON-encoded body on the mock response.
public func MockJSONBody<T: Encodable>(
  _ value: T,
  encoder: JSONEncoder = JSONEncoder()
) throws
  -> RespondComponent
{
  let data = try encoder.encode(value)
  return .jsonBody(HTTPBody(data))
}

/// Sets a response header.
public func ResponseHeader(_ name: HTTPHeaderName, _ value: HTTPHeaderValue) -> RespondComponent {
  .header(name, value)
}

// swiftlint:enable identifier_name
// swiftlint:enable file_length
