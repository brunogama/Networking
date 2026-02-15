import Foundation

// MARK: - Then Steps for Network Testing

/// Then step that verifies the response status code.
public struct ThenStatusIs: ThenStep, DescribableStep {
  private let expectedStatus: Int

  public var stepDescription: String {
    "response status is \(expectedStatus)"
  }

  /// Creates a status code assertion step.
  ///
  /// - Parameter status: Expected status code
  public init(_ status: Int) {
    self.expectedStatus = status
  }

  /// Creates a status code assertion step from HTTPStatus.
  ///
  /// - Parameter status: Expected HTTP status
  public init(_ status: HTTPStatus) {
    self.expectedStatus = status.rawValue
  }

  public func verify(context: ScenarioContext) throws {
    guard let response = context.lastResponse else {
      throw BDDError.noResponse
    }

    guard response.status.rawValue == expectedStatus else {
      throw BDDError.statusMismatch(
        expected: expectedStatus,
        actual: response.status.rawValue
      )
    }
  }
}

/// Then step that verifies the response is successful (2xx).
public struct ThenSuccessful: ThenStep, DescribableStep {
  public var stepDescription: String {
    "response is successful"
  }

  public init() {}

  public func verify(context: ScenarioContext) throws {
    guard let response = context.lastResponse else {
      throw BDDError.noResponse
    }

    guard response.status.isSuccess else {
      throw BDDError.notSuccessful(status: response.status.rawValue)
    }
  }
}

/// Then step that verifies a header exists.
public struct ThenHeaderExists: ThenStep, DescribableStep {
  private let headerName: String

  public var stepDescription: String {
    "response has header \"\(headerName)\""
  }

  /// Creates a header existence assertion step.
  ///
  /// - Parameter name: Header name to check
  public init(_ name: String) {
    self.headerName = name
  }

  public func verify(context: ScenarioContext) throws {
    guard let response = context.lastResponse else {
      throw BDDError.noResponse
    }

    guard response.headers[headerName] != nil else {
      throw BDDError.missingHeader(headerName)
    }
  }
}

/// Then step that verifies a header value.
public struct ThenHeaderEquals: ThenStep, DescribableStep {
  private let headerName: String
  private let expectedValue: String

  public var stepDescription: String {
    "response header \"\(headerName)\" equals \"\(expectedValue)\""
  }

  /// Creates a header value assertion step.
  ///
  /// - Parameters:
  ///   - name: Header name
  ///   - value: Expected value
  public init(_ name: String, equals value: String) {
    self.headerName = name
    self.expectedValue = value
  }

  public func verify(context: ScenarioContext) throws {
    guard let response = context.lastResponse else {
      throw BDDError.noResponse
    }

    guard let actualValue = response.headers[headerName] else {
      throw BDDError.missingHeader(headerName)
    }

    guard actualValue == expectedValue else {
      throw BDDError.headerValueMismatch(
        header: headerName,
        expected: expectedValue,
        actual: actualValue
      )
    }
  }
}

/// Then step that verifies the response body contains text.
public struct ThenBodyContains: ThenStep, DescribableStep {
  private let expectedContent: String

  public var stepDescription: String {
    "response body contains \"\(expectedContent)\""
  }

  /// Creates a body content assertion step.
  ///
  /// - Parameter content: Expected content
  public init(_ content: String) {
    self.expectedContent = content
  }

  public func verify(context: ScenarioContext) throws {
    guard let response = context.lastResponse else {
      throw BDDError.noResponse
    }

    guard let body = response.body else {
      throw BDDError.noBody
    }

    guard let bodyString = String(data: body, encoding: .utf8),
      bodyString.contains(expectedContent)
    else {
      throw BDDError.bodyDoesNotContain(expectedContent)
    }
  }
}

/// Then step that verifies the response body matches JSON.
public struct ThenBodyEquals<T: Decodable & Equatable & Sendable>: ThenStep, DescribableStep {
  private let expected: T
  private let decoder: JSONDecoder

  public var stepDescription: String {
    "response body equals expected value"
  }

  /// Creates a body equality assertion step.
  ///
  /// - Parameters:
  ///   - expected: Expected decoded value
  ///   - decoder: JSON decoder
  public init(_ expected: T, decoder: JSONDecoder = JSONDecoder()) {
    self.expected = expected
    self.decoder = decoder
  }

  public func verify(context: ScenarioContext) throws {
    guard let response = context.lastResponse else {
      throw BDDError.noResponse
    }

    guard let body = response.body else {
      throw BDDError.noBody
    }

    let actual = try decoder.decode(T.self, from: body)

    guard actual == expected else {
      throw BDDError.bodyDecodeMismatch(
        expected: String(describing: expected),
        actual: String(describing: actual)
      )
    }
  }
}

/// Then step that verifies the response body can be decoded.
public struct ThenBodyDecodable<T: Decodable & Sendable>: ThenStep, DescribableStep {
  private let type: T.Type
  private let decoder: JSONDecoder

  public var stepDescription: String {
    "response body is decodable as \(T.self)"
  }

  /// Creates a body decodability assertion step.
  ///
  /// - Parameters:
  ///   - type: Expected type
  ///   - decoder: JSON decoder
  public init(
    _ type: T.Type,
    decoder: JSONDecoder = JSONDecoder()
  ) {
    self.type = type
    self.decoder = decoder
  }

  public func verify(context: ScenarioContext) throws {
    guard let response = context.lastResponse else {
      throw BDDError.noResponse
    }

    guard let body = response.body else {
      throw BDDError.noBody
    }

    let decoded = try decoder.decode(T.self, from: body)

    // Store decoded value in context for later assertions
    context.setValue(decoded, forKey: "decodedBody")
  }
}

/// Then step that verifies an error occurred.
public struct ThenError: ThenStep, DescribableStep {
  private let expectedCategory: HTTPError.Category?

  public var stepDescription: String {
    if let category = expectedCategory {
      return "error occurred with category \(category)"
    }
    return "an error occurred"
  }

  /// Creates an error assertion step.
  ///
  /// - Parameter category: Optional expected error category
  public init(category: HTTPError.Category? = nil) {
    self.expectedCategory = category
  }

  public func verify(context: ScenarioContext) throws {
    guard let error = context.lastError else {
      if let category = expectedCategory {
        throw BDDError.expectedError(category)
      }
      throw BDDError.expectedError(.network(.noConnection))
    }

    if let expectedCategory = expectedCategory,
      let httpError = error as? HTTPError
    {
      guard httpError.category == expectedCategory else {
        throw BDDError.wrongErrorCategory(
          expected: expectedCategory,
          actual: httpError.category
        )
      }
    }
  }
}

/// Then step that verifies no error occurred.
public struct ThenNoError: ThenStep, DescribableStep {
  public var stepDescription: String {
    "no error occurred"
  }

  public init() {}

  public func verify(context: ScenarioContext) throws {
    if let error = context.lastError {
      throw error
    }
  }
}

/// Then step that verifies the response body is empty.
public struct ThenEmptyBody: ThenStep, DescribableStep {
  public var stepDescription: String {
    "response body is empty"
  }

  public init() {}

  public func verify(context: ScenarioContext) throws {
    guard let response = context.lastResponse else {
      throw BDDError.noResponse
    }

    if let body = response.body, !body.isEmpty {
      throw BDDError.bodyDecodeMismatch(expected: "empty", actual: "non-empty body")
    }
  }
}

/// Then step that executes a custom verification.
public struct ThenCustom: ThenStep, DescribableStep {
  private let description: String
  private let verification: @Sendable (ScenarioContext) throws -> Void

  public var stepDescription: String {
    description
  }

  /// Creates a custom Then step.
  ///
  /// - Parameters:
  ///   - description: Step description
  ///   - verification: The verification closure
  public init(
    _ description: String,
    verification: @escaping @Sendable (ScenarioContext) throws -> Void
  ) {
    self.description = description
    self.verification = verification
  }

  public func verify(context: ScenarioContext) throws {
    try verification(context)
  }
}

/// Then step that verifies a context value exists.
public struct ThenContextHas<T: Sendable & Equatable>: ThenStep, DescribableStep {
  private let key: ContextKey<T>
  private let expectedValue: T?

  public var stepDescription: String {
    if let expected = expectedValue {
      return "context \"\(key.name)\" equals \(expected)"
    }
    return "context has \"\(key.name)\""
  }

  /// Creates a context value assertion step.
  ///
  /// - Parameters:
  ///   - key: The context key
  ///   - value: Optional expected value
  public init(_ key: ContextKey<T>, equals value: T? = nil) {
    self.key = key
    self.expectedValue = value
  }

  public func verify(context: ScenarioContext) throws {
    guard let actual = context[key] else {
      throw BDDError.missingContextValue(key: key.name)
    }

    if let expected = expectedValue, actual != expected {
      throw BDDError.invalidContextType(
        key: key.name,
        expected: String(describing: expected),
        actual: String(describing: actual)
      )
    }
  }
}

// MARK: - Convenience Functions (prefixed to avoid conflicts)

/// Creates a status code assertion step.
public func thenStatusIs(_ code: Int) -> ThenStatusIs {
  ThenStatusIs(code)
}

/// Creates a status code assertion step from HTTPStatus.
public func thenStatusIs(_ status: HTTPStatus) -> ThenStatusIs {
  ThenStatusIs(status)
}

/// Creates a successful response assertion step.
public func thenSuccessful() -> ThenSuccessful {
  ThenSuccessful()
}

/// Creates a header exists assertion step.
public func thenHeaderExists(_ name: String) -> ThenHeaderExists {
  ThenHeaderExists(name)
}

/// Creates a header equals assertion step.
public func thenHeaderEquals(_ name: String, _ value: String) -> ThenHeaderEquals {
  ThenHeaderEquals(name, equals: value)
}

/// Creates a body contains assertion step.
public func thenBodyContains(_ content: String) -> ThenBodyContains {
  ThenBodyContains(content)
}

/// Creates a body equals assertion step.
public func thenBodyEquals<T: Decodable & Equatable & Sendable>(_ expected: T) -> ThenBodyEquals<T>
{
  ThenBodyEquals(expected)
}

/// Creates a body decodable assertion step.
public func thenBodyDecodableAs<T: Decodable & Sendable>(_ type: T.Type) -> ThenBodyDecodable<T> {
  ThenBodyDecodable(type)
}

/// Creates an error assertion step.
public func thenErrorOccurred(category: HTTPError.Category? = nil) -> ThenError {
  ThenError(category: category)
}

/// Creates a no error assertion step.
public func thenNoError() -> ThenNoError {
  ThenNoError()
}

/// Creates an empty body assertion step.
public func thenEmptyBody() -> ThenEmptyBody {
  ThenEmptyBody()
}

/// Creates a custom verification step.
public func thenVerify(
  _ description: String,
  _ verification: @escaping @Sendable (ScenarioContext) throws -> Void
) -> ThenCustom {
  ThenCustom(description, verification: verification)
}
