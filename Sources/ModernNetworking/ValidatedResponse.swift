import Foundation

// MARK: - Validated Response Types Hierarchy

/// Base protocol for validated responses
public protocol ValidatedResponseProtocol: Sendable {
  associatedtype ValueType: Sendable

  var response: HTTPResponse { get }
  var value: ValueType { get }
  var validationResults: [ValidationResult] { get }
}

/// A response that has passed all validation checks
public struct ValidatedResponse<T: Sendable>: ValidatedResponseProtocol, Sendable {
  public typealias ValueType = T

  public let response: HTTPResponse
  public let value: T
  public let validationResults: [ValidationResult]

  internal init(
    response: HTTPResponse,
    value: T,
    validationResults: [ValidationResult] = [.success]
  ) {
    self.response = response
    self.value = value
    self.validationResults = validationResults
  }

  /// Creates a validated response with a single validation result
  public init(response: HTTPResponse, value: T, validation: ValidationResult) {
    self.response = response
    self.value = value
    self.validationResults = [validation]
  }

  /// Indicates if all validations passed
  public var isValid: Bool {
    validationResults.allSatisfy(\.isValid)
  }

  /// Gets all validation errors
  public var validationErrors: [HTTPError] {
    validationResults.compactMap { result in
      switch result {
      case .success:
        return nil

      case .failure(let error):
        return error
      }
    }
  }
}

/// A response validated specifically for successful HTTP status codes
public struct SuccessValidatedResponse<T: Sendable>: ValidatedResponseProtocol, Sendable {
  public typealias ValueType = T

  public let response: HTTPResponse
  public let value: T
  public let validationResults: [ValidationResult]

  internal init(response: HTTPResponse, value: T) throws {
    guard response.status.isSuccess else {
      throw HTTPError.http(status: response.status, request: response.request, response: response)
    }

    self.response = response
    self.value = value
    self.validationResults = [.success]
  }
}

/// A response validated for specific content types
public struct ContentTypeValidatedResponse<T: Sendable>: ValidatedResponseProtocol, Sendable {
  public typealias ValueType = T

  public let response: HTTPResponse
  public let value: T
  public let validationResults: [ValidationResult]
  public let expectedContentType: String
  public let actualContentType: String?

  internal init(response: HTTPResponse, value: T, expectedContentType: String) throws {
    let actualContentType = response.headers["Content-Type"]?.lowercased()
    let normalizedActual = actualContentType?.components(separatedBy: ";").first?
      .trimmingCharacters(in: .whitespaces)

    guard normalizedActual == expectedContentType.lowercased() else {
      throw HTTPError(
        category: .configuration(
          "Expected Content-Type \(expectedContentType), got \(normalizedActual ?? "none")"
        ),
        request: response.request,
        response: response
      )
    }

    self.response = response
    self.value = value
    self.validationResults = [.success]
    self.expectedContentType = expectedContentType
    self.actualContentType = actualContentType
  }
}

/// A response with multiple validation layers applied
public struct MultiValidatedResponse<T: Sendable>: ValidatedResponseProtocol, Sendable {
  public typealias ValueType = T

  public let response: HTTPResponse
  public let value: T
  public let validationResults: [ValidationResult]
  public let appliedValidators: [String]

  /// Creates a multi-validated response by applying multiple validators
  public static func validate(
    response: HTTPResponse,
    value: T,
    validators: [(name: String, validator: any ResponseValidator)]
  ) throws -> MultiValidatedResponse<T> {
    var results: [ValidationResult] = []
    var names: [String] = []

    for (name, validator) in validators {
      let result = validator.validate(response)
      results.append(result)
      names.append(name)

      // Fail fast on first validation error
      switch result {
      case .success:
        continue

      case .failure(let error):
        throw error
      }
    }

    return Self(
      response: response,
      value: value,
      validationResults: results,
      appliedValidators: names
    )
  }
}

// MARK: - Status Code Validation Middleware

/// Middleware for validating HTTP status codes
public struct StatusCodeValidationMiddleware: Sendable {
  /// Configuration for status code validation
  public struct Configuration: Sendable {
    public let allowedStatusCodes: Set<Int>
    public let treatWarningsAsErrors: Bool
    public let customErrorHandler: (@Sendable (HTTPResponse) -> HTTPError)?

    public init(
      allowedStatusCodes: Set<Int>,
      treatWarningsAsErrors: Bool = false,
      customErrorHandler: (@Sendable (HTTPResponse) -> HTTPError)? = nil
    ) {
      self.allowedStatusCodes = allowedStatusCodes
      self.treatWarningsAsErrors = treatWarningsAsErrors
      self.customErrorHandler = customErrorHandler
    }

    /// Configuration for success status codes (200-299)
    public static let successOnly = Self(allowedStatusCodes: Set(200..<300))

    /// Configuration for success and redirection codes (200-399)
    public static let successAndRedirect = Self(allowedStatusCodes: Set(200..<400))

    /// Configuration that allows any status code
    public static let allowAll = Self(allowedStatusCodes: Set(100..<600))

    /// Configuration for specific status codes
    public static func specific(_ codes: Int...) -> Self {
      Self(allowedStatusCodes: Set(codes))
    }
  }

  private let configuration: Configuration

  public init(configuration: Configuration) {
    self.configuration = configuration
  }

  /// Validates a response according to the middleware configuration
  /// - Parameter response: The response to validate
  /// - Returns: ValidationResult indicating success or failure
  public func validate(_ response: HTTPResponse) -> ValidationResult {
    let statusCode = response.status.rawValue

    // Check if status code is allowed
    guard configuration.allowedStatusCodes.contains(statusCode) else {
      let error: HTTPError
      if let customHandler = configuration.customErrorHandler {
        error = customHandler(response)
      } else {
        error = HTTPError.http(
          status: response.status,
          request: response.request,
          response: response
        )
      }
      return .failure(error)
    }

    // Additional check for warning status codes if configured
    if configuration.treatWarningsAsErrors && response.status.isInformational {
      let error = HTTPError(
        category: .configuration("Informational status treated as error: \(statusCode)"),
        request: response.request,
        response: response
      )
      return .failure(error)
    }

    return .success
  }

  /// Creates a validated response using this middleware
  /// - Parameters:
  ///   - response: The response to validate
  ///   - value: The value to wrap in the validated response
  /// - Returns: A ValidatedResponse if validation passes
  /// - Throws: HTTPError if validation fails
  public func createValidatedResponse<T: Sendable>(
    response: HTTPResponse,
    value: T
  ) throws -> ValidatedResponse<T> {
    let result = validate(response)
    switch result {
    case .success:
      return ValidatedResponse(response: response, value: value, validation: result)

    case .failure(let error):
      throw error
    }
  }
}

// MARK: - Content-Type Checking Logic

/// Middleware for validating response content types
public struct ContentTypeValidationMiddleware: Sendable {
  /// Configuration for content type validation
  public struct Configuration: Sendable {
    public let expectedTypes: Set<String>
    public let ignoreCharset: Bool
    public let caseSensitive: Bool

    public init(
      expectedTypes: Set<String>,
      ignoreCharset: Bool = true,
      caseSensitive: Bool = false
    ) {
      self.expectedTypes =
        caseSensitive ? expectedTypes : Set(expectedTypes.map { $0.lowercased() })
      self.ignoreCharset = ignoreCharset
      self.caseSensitive = caseSensitive
    }

    /// Configuration for JSON content type
    public static let json = Self(expectedTypes: ["application/json"])

    /// Configuration for XML content types
    public static let xml = Self(expectedTypes: ["application/xml", "text/xml"])

    /// Configuration for plain text
    public static let plainText = Self(expectedTypes: ["text/plain"])

    /// Configuration for HTML
    public static let html = Self(expectedTypes: ["text/html"])

    /// Configuration for binary data
    public static let binary = Self(expectedTypes: ["application/octet-stream"])
  }

  private let configuration: Configuration

  public init(configuration: Configuration) {
    self.configuration = configuration
  }

  /// Validates a response's content type according to the middleware configuration
  /// - Parameter response: The response to validate
  /// - Returns: ValidationResult indicating success or failure
  public func validate(_ response: HTTPResponse) -> ValidationResult {
    guard let contentType = response.headers["Content-Type"] else {
      let error = HTTPError(
        category: .configuration("Missing Content-Type header"),
        request: response.request,
        response: response
      )
      return .failure(error)
    }

    let processedContentType: String
    if configuration.ignoreCharset {
      processedContentType =
        contentType.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespaces)
        ?? contentType
    } else {
      processedContentType = contentType.trimmingCharacters(in: .whitespaces)
    }

    let finalContentType =
      configuration.caseSensitive ? processedContentType : processedContentType.lowercased()

    if configuration.expectedTypes.contains(finalContentType) {
      return .success
    } else {
      let error = HTTPError(
        category: .configuration(
          "Expected Content-Type \(configuration.expectedTypes), got \(finalContentType)"
        ),
        request: response.request,
        response: response
      )
      return .failure(error)
    }
  }

  /// Creates a content-type validated response using this middleware
  /// - Parameters:
  ///   - response: The response to validate
  ///   - value: The value to wrap in the validated response
  /// - Returns: A ContentTypeValidatedResponse if validation passes
  /// - Throws: HTTPError if validation fails
  public func createValidatedResponse<T: Sendable>(
    response: HTTPResponse,
    value: T
  ) throws -> ContentTypeValidatedResponse<T> {
    let expectedType = configuration.expectedTypes.first ?? "unknown"
    return try ContentTypeValidatedResponse(
      response: response,
      value: value,
      expectedContentType: expectedType
    )
  }
}

// MARK: - Validation Extensions

extension HTTPResponse {
  /// Creates a success-validated response
  /// - Parameter value: The value to wrap
  /// - Returns: A SuccessValidatedResponse
  /// - Throws: HTTPError if the status is not successful
  public func successValidated<T: Sendable>(value: T) throws -> SuccessValidatedResponse<T> {
    try SuccessValidatedResponse(response: self, value: value)
  }

  /// Creates a multi-validated response with multiple validators
  /// - Parameters:
  ///   - value: The value to wrap
  ///   - validators: Array of named validators to apply
  /// - Returns: A MultiValidatedResponse
  /// - Throws: HTTPError if any validation fails
  public func multiValidated<T: Sendable>(
    value: T,
    validators: [(name: String, validator: any ResponseValidator)]
  ) throws -> MultiValidatedResponse<T> {
    try MultiValidatedResponse.validate(response: self, value: value, validators: validators)
  }

  /// Creates a validated response using status code middleware
  /// - Parameters:
  ///   - value: The value to wrap
  ///   - middleware: The status code validation middleware
  /// - Returns: A ValidatedResponse
  /// - Throws: HTTPError if validation fails
  public func validated<T: Sendable>(
    value: T,
    using middleware: StatusCodeValidationMiddleware
  ) throws -> ValidatedResponse<T> {
    try middleware.createValidatedResponse(response: self, value: value)
  }

  /// Creates a content-type validated response
  /// - Parameters:
  ///   - value: The value to wrap
  ///   - middleware: The content type validation middleware
  /// - Returns: A ContentTypeValidatedResponse
  /// - Throws: HTTPError if validation fails
  public func contentTypeValidated<T: Sendable>(
    value: T,
    using middleware: ContentTypeValidationMiddleware
  ) throws -> ContentTypeValidatedResponse<T> {
    try middleware.createValidatedResponse(response: self, value: value)
  }
}

// MARK: - Convenience Methods

extension ValidatedResponse {
  /// Extracts the value if validation passed, otherwise throws the first validation error
  /// - Returns: The validated value
  /// - Throws: HTTPError if validation failed
  public func extractValue() throws -> T {
    guard isValid else {
      throw validationErrors.first ?? HTTPError(category: .configuration("Validation failed"))
    }
    return value
  }

  /// Maps the validated value to a new type
  /// - Parameter transform: The transformation function
  /// - Returns: A new ValidatedResponse with the transformed value
  /// - Throws: Any error thrown by the transformation
  public func map<U: Sendable>(_ transform: (T) throws -> U) throws -> ValidatedResponse<U> {
    let newValue = try transform(value)
    return ValidatedResponse<U>(
      response: response,
      value: newValue,
      validationResults: validationResults
    )
  }

  /// Chains another validation on top of this validated response
  /// - Parameter validator: Additional validator to apply
  /// - Returns: A new ValidatedResponse with additional validation
  /// - Throws: HTTPError if the new validation fails
  public func additionalValidation(
    _ validator: any ResponseValidator
  ) throws -> ValidatedResponse<T> {
    let result = validator.validate(response)
    switch result {
    case .success:
      return ValidatedResponse(
        response: response,
        value: value,
        validationResults: validationResults + [result]
      )

    case .failure(let error):
      throw error
    }
  }
}
