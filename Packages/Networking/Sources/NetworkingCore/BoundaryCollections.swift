import Foundation

public struct HTTPHeaders: Sendable, Equatable, ExpressibleByDictionaryLiteral, Codable, Sequence,
  CustomStringConvertible
{
  private var storage: [HTTPHeaderName: HTTPHeaderValue]

  public init(_ storage: [HTTPHeaderName: HTTPHeaderValue] = [:]) {
    self.storage = storage
  }

  package init(_ rawStorage: [String: String]) {
    self.storage = Dictionary(
      uniqueKeysWithValues: rawStorage.map { (HTTPHeaderName($0.key), HTTPHeaderValue($0.value)) }
    )
  }

  public init(dictionaryLiteral elements: (HTTPHeaderName, HTTPHeaderValue)...) {
    self.storage = Dictionary(uniqueKeysWithValues: elements)
  }

  public var isEmpty: HTTPHeaderCollectionEmptyFlag {
    HTTPHeaderCollectionEmptyFlag(storage.isEmpty)
  }

  public var count: HTTPHeaderCollectionCount {
    HTTPHeaderCollectionCount(storage.count)
  }

  package var rawValue: [String: String] {
    Dictionary(uniqueKeysWithValues: storage.map { ($0.key.rawValue, $0.value.rawValue) })
  }

  public var keys: Dictionary<HTTPHeaderName, HTTPHeaderValue>.Keys {
    storage.keys
  }

  public var description: String {
    rawValue.description
  }

  public subscript(_ name: HTTPHeaderName) -> HTTPHeaderValue? {
    get { storage[name] }
    set { storage[name] = newValue }
  }

  package subscript(_ name: String) -> String? {
    get { storage[HTTPHeaderName(name)]?.rawValue }
    set {
      let headerName = HTTPHeaderName(name)
      if let newValue {
        storage[headerName] = HTTPHeaderValue(newValue)
      } else {
        storage.removeValue(forKey: headerName)
      }
    }
  }

  public func makeIterator() -> Dictionary<HTTPHeaderName, HTTPHeaderValue>.Iterator {
    storage.makeIterator()
  }

  public func map<T>(
    _ transform: ((key: HTTPHeaderName, value: HTTPHeaderValue)) throws -> T
  ) rethrows -> [T] {
    try storage.map(transform)
  }

  public func filter(
    _ isIncluded: ((key: HTTPHeaderName, value: HTTPHeaderValue)) throws -> Bool
  ) rethrows -> Self {
    Self(try Dictionary(uniqueKeysWithValues: storage.filter(isIncluded)))
  }

  public func merging(
    _ other: Self,
    uniquingKeysWith combine: (HTTPHeaderValue, HTTPHeaderValue) throws -> HTTPHeaderValue
  ) rethrows -> Self {
    Self(try storage.merging(other.storage, uniquingKeysWith: combine))
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(try container.decode([String: String].self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

package extension Sequence {
  func joined<Tag>(separator: String = "") -> String where Element == BoundaryString<Tag> {
    map(\.rawValue).joined(separator: separator)
  }

  func rawValues<Tag>() -> [String] where Element == BoundaryString<Tag> {
    map(\.rawValue)
  }
}
