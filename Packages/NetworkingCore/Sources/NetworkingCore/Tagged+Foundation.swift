import Foundation

extension Tagged where RawValue == String {
  /// Whether the string is empty.
  public var isEmpty: BoundaryStringEmptyFlag<Tag> {
    BoundaryStringEmptyFlag(rawValue.isEmpty)
  }

  /// Compares strings in the same domain without case sensitivity.
  public func caseInsensitiveCompare(_ other: Self) -> ComparisonResult {
    rawValue.caseInsensitiveCompare(other.rawValue)
  }

}

extension Tagged where RawValue == Data {
  /// Copies a contiguous sequence of bytes into owned data.
  public init<Bytes: ContiguousBytes>(_ bytes: Bytes) {
    self.init(rawValue: bytes.withUnsafeBytes { Data($0) })
  }

  /// The number of bytes in the value.
  public var count: BoundaryDataCount<Tag> { BoundaryDataCount(rawValue.count) }

  /// Whether the data contains no bytes.
  public var isEmpty: BoundaryDataEmptyFlag<Tag> { BoundaryDataEmptyFlag(rawValue.isEmpty) }

}

extension Tagged where RawValue == URL {
  /// Parses a URL from a tagged string, returning nil when Foundation rejects it.
  public init?<TextTag>(_ text: BoundaryString<TextTag>) { self.init(string: text.rawValue) }

  package init?(string: String) {
    guard let url = URL(string: string) else { return nil }
    self.init(rawValue: url)
  }

}

extension Tagged where RawValue == UUID {
  /// Creates a fresh identity in this domain.
  public init() { self.init(rawValue: UUID()) }

}
