// MARK: - Core HTTP Types

/// A structure representing an HTTP method.
///
/// Using a struct instead of an enum provides flexibility for custom methods.
public struct HTTPMethod: Sendable, Hashable {
  // MARK: - Standard Methods

  /// The GET method.
  public static let get = Self(rawValue: "GET")
  /// The POST method.
  public static let post = Self(rawValue: "POST")
  /// The PUT method.
  public static let put = Self(rawValue: "PUT")
  /// The PATCH method.
  public static let patch = Self(rawValue: "PATCH")
  /// The DELETE method.
  public static let delete = Self(rawValue: "DELETE")
  /// The HEAD method.
  public static let head = Self(rawValue: "HEAD")
  /// The OPTIONS method.
  public static let options = Self(rawValue: "OPTIONS")
  /// The CONNECT method.
  public static let connect = Self(rawValue: "CONNECT")
  /// The TRACE method.
  public static let trace = Self(rawValue: "TRACE")

  // MARK: - Properties

  /// The method name normalized to uppercase.
  public let rawValue: HTTPMethodName

  // MARK: - Initialization

  /// Creates a method by normalizing the supplied name to uppercase.
  public init(_ rawValue: HTTPMethodName) {
    self.rawValue = HTTPMethodName(rawValue.rawValue.uppercased())
  }

  /// Creates a method from a labeled name, normalized to uppercase.
  public init(rawValue: HTTPMethodName) {
    self.init(rawValue)
  }

  package init(rawValue: String) {
    self.init(rawValue: HTTPMethodName(rawValue))
  }

}
