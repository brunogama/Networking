import Foundation

// MARK: - Core HTTP Types

/// A structure representing an HTTP method.
/// Using a struct instead of an enum provides flexibility for custom methods.
public struct HTTPMethod: Sendable, Hashable {
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

  public let rawValue: HTTPMethodName

  // MARK: - Initialization

  public init(_ rawValue: HTTPMethodName) {
    self.rawValue = HTTPMethodName(rawValue.rawValue.uppercased())
  }

  public init(rawValue: HTTPMethodName) {
    self.init(rawValue)
  }

  package init(rawValue: String) {
    self.init(rawValue: HTTPMethodName(rawValue))
  }

  package var methodValue: String {
    rawValue.rawValue
  }
}
