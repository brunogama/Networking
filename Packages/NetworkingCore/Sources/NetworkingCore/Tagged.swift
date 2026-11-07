/// A value whose phantom tag prevents mixing identical representations from different domains.
///
/// Domains with validation rules must use a validating type instead.
public struct Tagged<Tag, RawValue>: RawRepresentable {
  /// The representation for explicit boundary conversion.
  public let rawValue: RawValue

  /// Creates a tagged value without adding constraints to its representation.
  public init(rawValue: RawValue) { self.rawValue = rawValue }

  /// Creates a tagged value from its representation.
  public init(_ rawValue: RawValue) { self.init(rawValue: rawValue) }
}

extension Tagged: Sendable where RawValue: Sendable {}
extension Tagged: Equatable where RawValue: Equatable {}
extension Tagged: Hashable where RawValue: Hashable {}

extension Tagged: Comparable where RawValue: Comparable {
  /// Compares values from the same domain.
  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

extension Tagged: Decodable where RawValue: Decodable {
  /// Decodes the representation directly, without an enclosing object.
  public init(from decoder: any Decoder) throws {
    self.init(rawValue: try decoder.singleValueContainer().decode(RawValue.self))
  }
}

extension Tagged: Encodable where RawValue: Encodable {
  /// Encodes the representation directly, without an enclosing object.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension Tagged: CustomStringConvertible where RawValue: CustomStringConvertible {
  /// The underlying value's textual representation.
  public var description: String { rawValue.description }
}

extension Tagged: CustomDebugStringConvertible where RawValue: CustomStringConvertible {
  /// The underlying value's textual representation.
  public var debugDescription: String { description }
}

extension Tagged where RawValue: AdditiveArithmetic {
  /// Adds values belonging to the same domain.
  public static func + (lhs: Self, rhs: Self) -> Self { Self(lhs.rawValue + rhs.rawValue) }

  /// Subtracts values belonging to the same domain.
  public static func - (lhs: Self, rhs: Self) -> Self { Self(lhs.rawValue - rhs.rawValue) }
}

extension Tagged: ExpressibleByIntegerLiteral where RawValue: ExpressibleByIntegerLiteral {
  /// Creates a value from an integer literal in its representation's range.
  public init(integerLiteral value: RawValue.IntegerLiteralType) {
    self.init(rawValue: RawValue(integerLiteral: value))
  }
}

extension Tagged: ExpressibleByFloatLiteral where RawValue: ExpressibleByFloatLiteral {
  /// Creates a value from a floating-point literal.
  public init(floatLiteral value: RawValue.FloatLiteralType) {
    self.init(rawValue: RawValue(floatLiteral: value))
  }
}

extension Tagged: ExpressibleByBooleanLiteral where RawValue == Bool {
  /// Creates a tagged Boolean literal.
  public init(booleanLiteral value: Bool) { self.init(rawValue: value) }
}

extension Tagged: ExpressibleByUnicodeScalarLiteral,
  ExpressibleByExtendedGraphemeClusterLiteral,
  ExpressibleByStringLiteral, ExpressibleByStringInterpolation
where RawValue == String {
  /// Creates a tagged string literal.
  public init(stringLiteral value: String) { self.init(rawValue: value) }

  /// Creates a tagged string from interpolation.
  public init(stringInterpolation: String.StringInterpolation) {
    self.init(rawValue: stringInterpolation.description)
  }
}
