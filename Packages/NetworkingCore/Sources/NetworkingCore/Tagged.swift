/// A value whose phantom tag prevents mixing identical representations from different domains.
///
/// Domains with validation rules must use a validating type instead.
public struct Tagged<Tag, RawValue>: RawRepresentable {

  public let rawValue: RawValue

  public init(rawValue: RawValue) { self.rawValue = rawValue }

  public init(_ rawValue: RawValue) { self.init(rawValue: rawValue) }
}

extension Tagged: Sendable where RawValue: Sendable {}
extension Tagged: Equatable where RawValue: Equatable {}
extension Tagged: Hashable where RawValue: Hashable {}

extension Tagged: Comparable where RawValue: Comparable {

  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

extension Tagged: Decodable where RawValue: Decodable {

  public init(from decoder: any Decoder) throws {
    self.init(rawValue: try decoder.singleValueContainer().decode(RawValue.self))
  }
}

extension Tagged: Encodable where RawValue: Encodable {

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension Tagged: CustomStringConvertible where RawValue: CustomStringConvertible {

  public var description: String { rawValue.description }
}

extension Tagged: CustomDebugStringConvertible where RawValue: CustomStringConvertible {

  public var debugDescription: String { description }
}

extension Tagged where RawValue: AdditiveArithmetic {

  public static func + (lhs: Self, rhs: Self) -> Self { Self(lhs.rawValue + rhs.rawValue) }

  public static func - (lhs: Self, rhs: Self) -> Self { Self(lhs.rawValue - rhs.rawValue) }
}

extension Tagged: ExpressibleByIntegerLiteral where RawValue: ExpressibleByIntegerLiteral {

  public init(integerLiteral value: RawValue.IntegerLiteralType) {
    self.init(rawValue: RawValue(integerLiteral: value))
  }
}

extension Tagged: ExpressibleByFloatLiteral where RawValue: ExpressibleByFloatLiteral {

  public init(floatLiteral value: RawValue.FloatLiteralType) {
    self.init(rawValue: RawValue(floatLiteral: value))
  }
}

extension Tagged: ExpressibleByBooleanLiteral where RawValue == Bool {

  public init(booleanLiteral value: Bool) { self.init(rawValue: value) }
}

extension Tagged: ExpressibleByUnicodeScalarLiteral,
  ExpressibleByExtendedGraphemeClusterLiteral,
  ExpressibleByStringLiteral, ExpressibleByStringInterpolation
where RawValue == String {

  public init(stringLiteral value: String) { self.init(rawValue: value) }

  public init(stringInterpolation: String.StringInterpolation) {
    self.init(rawValue: stringInterpolation.description)
  }
}
