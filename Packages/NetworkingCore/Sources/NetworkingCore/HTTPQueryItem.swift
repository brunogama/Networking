/// A typed query item whose optional value preserves a key-only query parameter.
public struct HTTPQueryItem: Sendable, Hashable {
  /// The parameter name.
  public let name: QueryParameterName

  /// The parameter value, or nil for a key-only parameter.
  public let value: String?

  /// Creates a query item from a typed name and an optional value.
  public init(name: QueryParameterName, value: String?) {
    self.name = name
    self.value = value
  }
}
