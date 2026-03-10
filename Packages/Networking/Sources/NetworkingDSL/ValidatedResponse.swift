import Foundation
import NetworkingCore

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
    validationResults: [ValidationResult] = [ValidationResult.success]
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
  public var isValid: ValidationFlag {
    ValidationFlag(validationResults.allSatisfy { $0.isValid.rawValue })
  }

  /// Gets all validation errors
  public var validationErrors: [HTTPError] {
    validationResults.compactMap { result in
      switch result {
      case .success:
        return nil as HTTPError?

      case .failure(let error):
        return error
      }
    }
  }

  /// Creates a successful validated response
  public static func success(response: HTTPResponse, value: T) -> ValidatedResponse<T> {
    Self(response: response, value: value, validationResults: [ValidationResult.success])
  }

  /// Creates a failed validated response
  public static func failure(
    response: HTTPResponse,
    value: T,
    error: HTTPError
  ) -> ValidatedResponse<T> {
    Self(response: response, value: value, validationResults: [ValidationResult.failure(error)])
  }
}

// MARK: - Convenience Methods

extension ValidatedResponse {
  /// Extracts the value if validation passed, otherwise throws the first validation error
  /// - Returns: The validated value
  /// - Throws: HTTPError if validation failed
  public func extractValue() throws -> T {
    guard isValid.rawValue else {
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

  /// Applies a validation that doesn't change the value type
  /// - Parameter validation: Validation closure that may throw
  /// - Returns: Same ValidatedResponse if validation passes
  /// - Throws: HTTPError if validation fails
  public func ensuring(
    _ validation: (HTTPResponse, T) throws -> Void
  ) throws -> ValidatedResponse<T> {
    try validation(response, value)
    return self
  }
}
