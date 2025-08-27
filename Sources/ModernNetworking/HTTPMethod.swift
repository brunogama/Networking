import Foundation

// MARK: - Core HTTP Types

/// A structure representing an HTTP method.
/// Using a struct instead of an enum provides flexibility for custom methods.
public struct HTTPMethod: Sendable, Hashable, ExpressibleByStringLiteral {
  // MARK: - Standard Methods

  public static let get = Self(rawValue: "GET")
  public static let post = Self(rawValue: "POST")
  public static let put = Self(rawValue: "PUT")
  public static let patch = Self(rawValue: "PATCH")
  public static let delete = Self(rawValue: "DELETE")
  public static let head = Self(rawValue: "HEAD")
  public static let options = Self(rawValue: "OPTIONS")
  public static let connect = Self(rawValue: "CONNECT")
  public static let trace = Self(rawValue: "TRACE")

  // MARK: - Properties

  public let rawValue: String

  // MARK: - Initialization

  public init(rawValue: String) {
    self.rawValue = rawValue.uppercased()
  }

  public init(stringLiteral value: String) {
    self.init(rawValue: value)
  }
}
