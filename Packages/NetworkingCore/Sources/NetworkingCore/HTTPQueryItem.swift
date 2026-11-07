/// A typed query item whose optional value preserves a key-only query parameter.
public struct HTTPQueryItem: Sendable, Hashable {

  public let name: QueryParameterName

  public let value: String?

  public init(name: QueryParameterName, value: String?) {
    self.name = name
    self.value = value
  }
}
