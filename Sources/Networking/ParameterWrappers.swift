import Foundation

// MARK: - API Parameter Marker Attributes
//
// IMPORTANT: Swift has a fundamental limitation where neither macros nor property wrappers
// can be attached to function parameters within protocol declarations.
//
// The @API macro reads parameter annotations from the syntax tree, but Swift validates
// that any @attribute on a parameter must be either:
// 1. A valid attached macro (but peer macros can't attach to parameters)
// 2. A valid property wrapper (but property wrappers can't be used in protocols)
//
// Until Swift adds support for custom parameter attributes that don't require
// implementation, the @API macro approach cannot work with declarative protocols.
//
// WORKAROUND: Use the RequestBuilder DSL directly for type-safe request building.
// See the MacroSampleApp for examples of the manual implementation pattern.
//
// The property wrappers below are kept for potential future use in concrete
// implementations (not protocols) where Swift does allow property wrappers on parameters.

/// Namespace for API parameter property wrappers.
///
/// These property wrappers can be used on concrete function parameters (not in protocols)
/// to provide metadata about how parameters should be used in HTTP requests.
///
/// **Note**: Due to Swift limitations, these cannot be used in protocol definitions.
/// Use the RequestBuilder DSL directly instead.
public enum Param {

  // MARK: - Path Parameter

  /// A property wrapper that marks a parameter as a URL path component.
  ///
  /// **Important**: Cannot be used in protocol definitions due to Swift limitations.
  /// Use the RequestBuilder DSL directly for protocol-based APIs.
  @propertyWrapper
  public struct Path<Value: LosslessStringConvertible & Sendable>: Sendable {
    public var wrappedValue: Value
    public let name: String?

    public init(wrappedValue: Value, _ name: String? = nil) {
      self.wrappedValue = wrappedValue
      self.name = name
    }

    public init(wrappedValue: Value) {
      self.wrappedValue = wrappedValue
      self.name = nil
    }
  }

  // MARK: - Query Parameter

  /// A property wrapper that marks a parameter as a URL query parameter.
  ///
  /// **Important**: Cannot be used in protocol definitions due to Swift limitations.
  /// Use the RequestBuilder DSL directly for protocol-based APIs.
  @propertyWrapper
  public struct Query<Value: LosslessStringConvertible & Sendable>: Sendable {
    public var wrappedValue: Value
    public let name: String?

    public init(wrappedValue: Value, _ name: String? = nil) {
      self.wrappedValue = wrappedValue
      self.name = name
    }

    public init(wrappedValue: Value) {
      self.wrappedValue = wrappedValue
      self.name = nil
    }
  }

  // MARK: - Body Parameter

  /// A property wrapper that marks a parameter as the request body.
  ///
  /// **Important**: Cannot be used in protocol definitions due to Swift limitations.
  /// Use the RequestBuilder DSL directly for protocol-based APIs.
  @propertyWrapper
  public struct Body<Value: Encodable & Sendable>: Sendable {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
      self.wrappedValue = wrappedValue
    }
  }

  // MARK: - Header Parameter

  /// A property wrapper that marks a parameter as an HTTP header.
  ///
  /// **Important**: Cannot be used in protocol definitions due to Swift limitations.
  /// Use the RequestBuilder DSL directly for protocol-based APIs.
  @propertyWrapper
  public struct Header<Value: LosslessStringConvertible & Sendable>: Sendable {
    public var wrappedValue: Value
    public let name: String

    public init(wrappedValue: Value, _ name: String) {
      self.wrappedValue = wrappedValue
      self.name = name
    }
  }
}
