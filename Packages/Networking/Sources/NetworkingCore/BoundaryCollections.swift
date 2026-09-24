import Foundation

public struct HTTPHeaders: Sendable, Equatable, ExpressibleByDictionaryLiteral, Codable, Sequence,
  CustomStringConvertible
{
  private var storage: [HTTPHeaderName: HTTPHeaderValue]

  public init(_ storage: [HTTPHeaderName: HTTPHeaderValue] = [:]) {
    self.storage = [:]
    for (name, value) in storage {
      self[name] = value
    }
  }

  package init(_ rawStorage: [String: String]) {
    self.init(
      Dictionary(
        uniqueKeysWithValues: rawStorage.map {
          (HTTPHeaderName($0.key), HTTPHeaderValue($0.value))
        }
      )
    )
  }

  public init(dictionaryLiteral elements: (HTTPHeaderName, HTTPHeaderValue)...) {
    self.storage = [:]
    for (name, value) in elements {
      self[name] = value
    }
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

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.count == rhs.count && lhs.storage.allSatisfy { rhs[$0.key] == $0.value }
  }

  public subscript(_ name: HTTPHeaderName) -> HTTPHeaderValue? {
    get { matchingKey(for: name).flatMap { storage[$0] } }
    set {
      let key = matchingKey(for: name) ?? name
      storage[key] = newValue
    }
  }

  package subscript(_ name: String) -> String? {
    get { self[HTTPHeaderName(name)]?.rawValue }
    set {
      let headerName = HTTPHeaderName(name)
      self[headerName] = newValue.map { HTTPHeaderValue($0) }
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
    var result = self
    for (name, value) in other {
      if let existing = result[name] {
        result[name] = try combine(existing, value)
      } else {
        result[name] = value
      }
    }
    return result
  }

  private func matchingKey(for name: HTTPHeaderName) -> HTTPHeaderName? {
    storage.keys.first { $0.rawValue.caseInsensitiveCompare(name.rawValue) == .orderedSame }
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
