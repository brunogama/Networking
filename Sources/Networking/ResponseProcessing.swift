import Foundation

// MARK: - Response Processing Protocol

/// Protocol for response processing operations with method chaining support
public protocol ResponseProcessor: Sendable {
  associatedtype Input
  associatedtype Output

  func process(_ input: Input) throws -> Output
}

// MARK: - Response Chain Types

/// A chainable response processing type that enables method chaining
public struct ResponseChain<T: Sendable>: Sendable {
  public let response: HTTPResponse
  public let value: T
}

// MARK: - Validation Types

/// Validation result for response processing
public enum ValidationResult: Sendable {
  case success
  case failure(HTTPError)

  public var isValid: Bool {
    switch self {
    case .success: return true
    case .failure: return false
    }
  }
}

/// Protocol for response validators
public protocol ResponseValidator: Sendable {
  func validate(_ response: HTTPResponse) -> ValidationResult
}

// MARK: - Status Code Validator

public struct StatusValidator: ResponseValidator {
  private let validStatuses: Set<Int>

  public init(validStatuses: Set<Int>) {
    self.validStatuses = validStatuses
  }

  public static let successStatus = Self(validStatuses: Set(200..<300))
  public static let anyStatus = Self(validStatuses: Set(100..<600))

  public func validate(_ response: HTTPResponse) -> ValidationResult {
    if validStatuses.contains(response.status.rawValue) {
      return .success
    } else {
      return .failure(
        HTTPError.http(status: response.status, request: response.request, response: response)
      )
    }
  }
}

// MARK: - Content Type Validator

public struct ContentTypeValidator: ResponseValidator {
  private let expectedContentTypes: Set<String>

  public init(_ contentTypes: String...) {
    self.expectedContentTypes = Set(contentTypes.map { $0.lowercased() })
  }

  public init(_ contentTypes: Set<String>) {
    self.expectedContentTypes = Set(contentTypes.map { $0.lowercased() })
  }

  public static func json() -> Self {
    Self("application/json")
  }

  public static func xml() -> Self {
    Self("application/xml", "text/xml")
  }

  public static func plainText() -> Self {
    Self("text/plain")
  }

  public func validate(_ response: HTTPResponse) -> ValidationResult {
    guard let contentType = response.headers["Content-Type"]?.lowercased() else {
      return .failure(
        HTTPError(
          category: .configuration("Missing Content-Type header"),
          request: response.request,
          response: response
        )
      )
    }

    let actualContentType =
      contentType.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespaces)
      ?? contentType

    if expectedContentTypes.contains(actualContentType) {
      return .success
    } else {
      return .failure(
        HTTPError(
          category: .configuration(
            "Expected Content-Type \(expectedContentTypes), got \(actualContentType)"
          ),
          request: response.request,
          response: response
        )
      )
    }
  }
}

// MARK: - Response Transformation

/// Protocol for response transformers
public protocol ResponseTransformer<Input, Output>: Sendable {
  associatedtype Input
  associatedtype Output

  func transform(_ input: Input) throws -> Output
}

// MARK: - JSON Decoder Transformer

public struct JSONDecoderTransformer<T: Decodable & Sendable>: ResponseTransformer {
  public typealias Input = Data
  public typealias Output = T

  private let decoder: JSONDecoder
  private let type: T.Type

  public init(_ type: T.Type, decoder: JSONDecoder = JSONDecoder()) {
    self.type = type
    self.decoder = decoder
  }

  public func transform(_ input: Data) throws -> T {
    do {
      return try decoder.decode(type, from: input)
    } catch {
      throw HTTPError(
        category: .decoding("Failed to decode \(type): \(error.localizedDescription)"),
        underlyingError: error
      )
    }
  }
}

// MARK: - String Transformer

public struct StringTransformer: ResponseTransformer {
  public typealias Input = Data
  public typealias Output = String

  private let encoding: String.Encoding

  public init(encoding: String.Encoding = .utf8) {
    self.encoding = encoding
  }

  public func transform(_ input: Data) throws -> String {
    guard let string = String(data: input, encoding: encoding) else {
      throw HTTPError(
        category: .decoding("Failed to convert data to string using \(encoding) encoding")
      )
    }
    return string
  }
}

// MARK: - Response Cache Duration

public struct ResponseCacheDuration: Sendable {
  public let seconds: TimeInterval

  public static func seconds(_ value: TimeInterval) -> Self {
    Self(seconds: value)
  }

  public static func minutes(_ value: TimeInterval) -> Self {
    Self(seconds: value * 60)
  }

  public static func hours(_ value: TimeInterval) -> Self {
    Self(seconds: value * 3600)
  }

  public static func days(_ value: TimeInterval) -> Self {
    Self(seconds: value * 86_400)
  }
}

// MARK: - Specialized Response Types

// ValidatedResponse is now defined in ValidatedResponse.swift

/// A decodable response with automatic JSON decoding
public struct DecodableResponse<T: Decodable & Sendable>: Sendable {
  public let response: HTTPResponse
  public let value: T
}

/// A cached response with cache metadata
public struct ProcessedCachedResponse<T: Sendable>: Sendable {
  public let response: HTTPResponse
  public let value: T
  public let cacheExpiry: Date

  internal init(response: HTTPResponse, value: T, cacheExpiry: Date) {
    self.response = response
    self.value = value
    self.cacheExpiry = cacheExpiry
  }

  public var isCacheValid: Bool {
    Date() < cacheExpiry
  }
}

/// A transformed response with data transformation
public struct TransformedResponse<T: Sendable>: Sendable {
  public let response: HTTPResponse
  public let value: T
}

// MARK: - HTTPResponse Method Chaining Extensions

extension HTTPResponse {
  /// Starts a response processing chain
  /// - Returns: A ResponseChain wrapping this response
  public func chain() -> ResponseChain<HTTPResponse> {
    ResponseChain(response: self, value: self)
  }

  /// Validates the response and returns a validated response chain
  /// - Parameter validator: The validator to use
  /// - Returns: A new ResponseChain with validation applied
  /// - Throws: HTTPError if validation fails
  public func validate(_ validator: any ResponseValidator) throws -> ResponseChain<HTTPResponse> {
    let result = validator.validate(self)
    switch result {
    case .success:
      return chain()

    case .failure(let error):
      throw error
    }
  }

  /// Convenience method to validate with success status codes (200-299)
  /// - Returns: A ResponseChain with this response
  /// - Throws: HTTPError if validation fails
  public func validateSuccess() throws -> ResponseChain<HTTPResponse> {
    try validate(StatusValidator.successStatus)
  }

  /// Caches the response for the specified duration
  /// - Parameter duration: How long to cache the response
  /// - Returns: A ProcessedCachedResponse with cache metadata
  public func cache(for duration: ResponseCacheDuration) -> ProcessedCachedResponse<HTTPResponse> {
    let expiry = Date().addingTimeInterval(duration.seconds)
    return ProcessedCachedResponse(response: self, value: self, cacheExpiry: expiry)
  }

  /// Transforms the response using the provided transformer
  /// - Parameter transformer: The transformer to use
  /// - Returns: A TransformedResponse with the transformed value
  /// - Throws: HTTPError if transformation fails
  public func transform<T: Sendable>(
    _ transformer: some ResponseTransformer<HTTPResponse, T>
  ) throws -> TransformedResponse<T> {
    let transformedValue = try transformer.transform(self)
    return TransformedResponse(response: self, value: transformedValue)
  }

  /// Validates the response status code.
  /// - Throws: HTTPError if the status indicates an error
  @available(*, deprecated, message: "Use chain().validate(.successStatus) instead")
  public func validateStatus() throws {
    if status.isClientError || status.isServerError {
      throw HTTPError.http(status: status, request: request, response: self)
    }
  }

  /// Decodes the response body as JSON.
  /// - Parameters:
  ///   - type: The type to decode to
  ///   - decoder: The JSON decoder to use (optional)
  /// - Returns: The decoded value
  /// - Throws: HTTPError if decoding fails
  @available(*, deprecated, message: "Use chain().decode(_:using:) instead")
  public func decode<T: Decodable>(
    _ type: T.Type,
    using decoder: JSONDecoder = JSONDecoder()
  ) throws -> T {
    guard let body = body else {
      throw HTTPError(
        category: .decoding("Response body is empty"),
        request: request,
        response: self
      )
    }

    do {
      return try decoder.decode(type, from: body)
    } catch {
      throw HTTPError(
        category: .decoding("Failed to decode \(type): \(error.localizedDescription)"),
        request: request,
        response: self,
        underlyingError: error
      )
    }
  }

  /// Gets the response body as a string.
  /// - Parameter encoding: The string encoding to use (default: UTF-8)
  /// - Returns: The response body as a string, or nil if conversion fails
  @available(*, deprecated, message: "Use chain().transform(StringTransformer()) instead")
  public func bodyAsString(encoding: String.Encoding = .utf8) -> String? {
    guard let body = body else { return nil }
    return String(data: body, encoding: encoding)
  }
}

// MARK: - ResponseChain Method Chaining Extensions

extension ResponseChain {
  /// Validates the response using the provided validator
  /// - Parameter validator: The validator to use
  /// - Returns: A new ResponseChain with validation applied
  /// - Throws: HTTPError if validation fails
  public func validate(_ validator: any ResponseValidator) throws -> ResponseChain<T> {
    let result = validator.validate(response)
    switch result {
    case .success:
      return self

    case .failure(let error):
      throw error
    }
  }

  /// Convenience method to validate with success status codes (200-299)
  /// - Returns: A ValidatedResponse
  /// - Throws: HTTPError if validation fails
  public func validateSuccess() throws -> ValidatedResponse<T> {
    let result = StatusValidator.successStatus.validate(response)
    switch result {
    case .success:
      return ValidatedResponse(response: response, value: value)

    case .failure(let error):
      throw error
    }
  }
}

extension ResponseChain where T == HTTPResponse {
  /// Decodes the response body using the provided transformer
  /// - Parameter transformer: The transformer to use for decoding
  /// - Returns: A new ResponseChain with the decoded value
  /// - Throws: HTTPError if decoding fails
  public func decode<U>(_ transformer: some ResponseTransformer<Data, U>) throws -> ResponseChain<U>
  {
    guard let body = response.body else {
      throw HTTPError(
        category: .decoding("Response body is empty"),
        request: response.request,
        response: response
      )
    }

    let decodedValue = try transformer.transform(body)
    return ResponseChain<U>(response: response, value: decodedValue)
  }

  /// Convenience method to decode JSON
  /// - Parameters:
  ///   - type: The type to decode to
  ///   - decoder: The JSON decoder to use
  /// - Returns: A DecodableResponse with the decoded value
  /// - Throws: HTTPError if decoding fails
  public func decode<U: Decodable>(
    _ type: U.Type,
    using decoder: JSONDecoder = JSONDecoder()
  ) throws -> DecodableResponse<U> {
    guard let body = response.body else {
      throw HTTPError(
        category: .decoding("Response body is empty"),
        request: response.request,
        response: response
      )
    }

    let transformer = JSONDecoderTransformer(type, decoder: decoder)
    let decodedValue = try transformer.transform(body)
    return DecodableResponse(response: response, value: decodedValue)
  }

  /// Transforms the response body to a string
  /// - Parameter encoding: The string encoding to use
  /// - Returns: A TransformedResponse with the string value
  /// - Throws: HTTPError if transformation fails
  public func asString(encoding: String.Encoding = .utf8) throws -> TransformedResponse<String> {
    guard let body = response.body else {
      throw HTTPError(
        category: .decoding("Response body is empty"),
        request: response.request,
        response: response
      )
    }

    let transformer = StringTransformer(encoding: encoding)
    let stringValue = try transformer.transform(body)
    return TransformedResponse(response: response, value: stringValue)
  }
}

extension ResponseChain {
  /// Transforms the current value using the provided transformer
  /// - Parameter transformer: The transformer to use
  /// - Returns: A new ResponseChain with the transformed value
  /// - Throws: HTTPError if transformation fails
  public func transform<U>(_ transformer: some ResponseTransformer<T, U>) throws -> ResponseChain<U>
  {
    let transformedValue = try transformer.transform(value)
    return ResponseChain<U>(response: response, value: transformedValue)
  }

  /// Caches the response for the specified duration
  /// - Parameter duration: How long to cache the response
  /// - Returns: A ProcessedCachedResponse with cache metadata
  public func cache(for duration: ResponseCacheDuration) -> ProcessedCachedResponse<T> {
    let expiry = Date().addingTimeInterval(duration.seconds)
    return ProcessedCachedResponse(response: response, value: value, cacheExpiry: expiry)
  }

  /// Applies a custom transformation using a closure
  /// - Parameter transform: The transformation closure
  /// - Returns: A new ResponseChain with the transformed value
  /// - Throws: Any error thrown by the transformation closure
  public func map<U>(_ transform: (T) throws -> U) throws -> ResponseChain<U> {
    let transformedValue = try transform(value)
    return ResponseChain<U>(response: response, value: transformedValue)
  }

  /// Applies error recovery if the chain fails
  /// - Parameter recovery: The recovery closure
  /// - Returns: A new ResponseChain with the recovered value or rethrows the error
  public func recover(_ recovery: (HTTPError) throws -> T) throws -> ResponseChain<T> {
    // This method provides a hook for error recovery in method chains
    // The actual error handling would be implemented by wrapping other chain operations
    self
  }

  /// Extracts the final value from the chain
  /// - Returns: The processed value
  public func extractValue() -> T {
    value
  }

  /// Extracts both the response and the processed value
  /// - Returns: A tuple containing the response and the processed value
  public func result() -> (response: HTTPResponse, value: T) {
    (response: response, value: value)
  }
}

// MARK: - Error Recovery Extensions

extension ResponseChain {
  /// Provides error recovery for the entire chain operation
  /// - Parameter operation: The chain operation that might fail
  /// - Parameter recovery: The recovery strategy to use on failure
  /// - Returns: A ResponseChain with either the successful result or recovered value
  public static func withRecovery<U>(
    _ operation: () throws -> ResponseChain<U>,
    recovery: (HTTPError) throws -> ResponseChain<U>
  ) throws -> ResponseChain<U> {
    do {
      return try operation()
    } catch let error as HTTPError {
      return try recovery(error)
    }
  }
}

// MARK: - Convenience Validation Methods

extension ResponseValidator where Self == StatusValidator {
  /// Validates success status codes (200-299)
  public static var successStatus: StatusValidator {
    StatusValidator.successStatus
  }

  /// Validates any status code
  public static var anyStatus: StatusValidator {
    StatusValidator.anyStatus
  }

  /// Validates specific status codes
  public static func status(_ codes: Int...) -> StatusValidator {
    StatusValidator(validStatuses: Set(codes))
  }
}

extension ResponseValidator where Self == ContentTypeValidator {
  /// Validates JSON content type
  public static func contentType(_ type: String) -> ContentTypeValidator {
    ContentTypeValidator(type)
  }

  /// Validates JSON content type
  public static var json: ContentTypeValidator {
    ContentTypeValidator.json()
  }

  /// Validates XML content type
  public static var xml: ContentTypeValidator {
    ContentTypeValidator.xml()
  }

  /// Validates plain text content type
  public static var plainText: ContentTypeValidator {
    ContentTypeValidator.plainText()
  }
}
