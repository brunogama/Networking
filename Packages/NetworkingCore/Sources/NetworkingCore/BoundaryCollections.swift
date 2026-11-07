import Foundation

/// A collection of HTTP headers with case-insensitive name lookup.
public struct HTTPHeaders: Sendable, Equatable, ExpressibleByDictionaryLiteral,
  Codable, Sequence, CustomStringConvertible
{
  private var storage: [HTTPHeaderName: HTTPHeaderValue]

  /// Creates headers from wrapped names and values.
  public init(_ storage: [HTTPHeaderName: HTTPHeaderValue] = [:]) {
    self.storage = [:]
    for (name, value) in storage {
      self[name] = value
    }
  }

  /// Creates headers from their raw string representation.
  ///
  /// Case-insensitive duplicate names collapse; the retained value is unspecified.
  public init(rawValue: [String: String]) {
    self.init(rawValue)
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

  /// Creates headers from a dictionary literal.
  public init(
    dictionaryLiteral elements: (HTTPHeaderName, HTTPHeaderValue)...
  ) {
    self.storage = [:]
    for (name, value) in elements {
      self[name] = value
    }
  }

  /// Whether the collection has no headers.
  public var isEmpty: HTTPHeaderCollectionEmptyFlag {
    HTTPHeaderCollectionEmptyFlag(storage.isEmpty)
  }

  /// The number of headers in the collection.
  public var count: HTTPHeaderCollectionCount {
    HTTPHeaderCollectionCount(storage.count)
  }

  /// The raw string representation for interoperability at a boundary.
  public var rawValue: [String: String] {
    Dictionary(
      uniqueKeysWithValues: storage.map { ($0.key.rawValue, $0.value.rawValue) }
    )
  }

  /// The stored header names.
  public var keys: Dictionary<HTTPHeaderName, HTTPHeaderValue>.Keys {
    storage.keys
  }

  /// A textual description of the raw headers.
  public var description: String {
    rawValue.description
  }

  /// Compares headers using case-insensitive names and exact values.
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.count == rhs.count && lhs.storage.allSatisfy { rhs[$0.key] == $0.value }
  }

  /// Gets or sets a header by its case-insensitive name.
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

  /// Returns an iterator over the stored header entries.
  public func makeIterator()
    -> Dictionary<HTTPHeaderName, HTTPHeaderValue>.Iterator
  {
    storage.makeIterator()
  }

  /// Transforms each header entry.
  public func map<T>(
    _ transform: ((key: HTTPHeaderName, value: HTTPHeaderValue)) throws -> T
  ) rethrows -> [T] {
    try storage.map(transform)
  }

  /// Returns the entries that satisfy the predicate.
  public func filter(
    _ isIncluded: ((key: HTTPHeaderName, value: HTTPHeaderValue)) throws -> Bool
  ) rethrows -> Self {
    Self(try Dictionary(uniqueKeysWithValues: storage.filter(isIncluded)))
  }

  /// Returns the semantic result of merging another collection.
  ///
  /// When `combine` is associative, grouping any sequence of merges differently produces
  /// semantically equal headers. Header-name casing is ignored by that equality.
  public func merging(
    _ other: Self,
    uniquingKeysWith combine: (
      HTTPHeaderValue, HTTPHeaderValue
    ) throws -> HTTPHeaderValue
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
    storage.keys.first {
      $0.rawValue.caseInsensitiveCompare(name.rawValue) == .orderedSame
    }
  }

  /// Decodes headers from their raw string representation.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(try container.decode([String: String].self))
  }

  /// Encodes headers using their raw string representation.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
