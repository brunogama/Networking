import Foundation

extension Tagged where RawValue == String {

  public var isEmpty: BoundaryStringEmptyFlag<Tag> {
    BoundaryStringEmptyFlag(rawValue.isEmpty)
  }

  public func caseInsensitiveCompare(_ other: Self) -> ComparisonResult {
    rawValue.caseInsensitiveCompare(other.rawValue)
  }

}

extension Tagged where RawValue == Data {

  public init<Bytes: ContiguousBytes>(_ bytes: Bytes) {
    self.init(rawValue: bytes.withUnsafeBytes { Data($0) })
  }

  public var count: BoundaryDataCount<Tag> { BoundaryDataCount(rawValue.count) }

  public var isEmpty: BoundaryDataEmptyFlag<Tag> { BoundaryDataEmptyFlag(rawValue.isEmpty) }

}

extension Tagged where RawValue == URL {

  public init?<TextTag>(_ text: BoundaryString<TextTag>) { self.init(string: text.rawValue) }

  package init?(string: String) {
    guard let url = URL(string: string) else { return nil }
    self.init(rawValue: url)
  }

}

extension Tagged where RawValue == UUID {

  public init() { self.init(rawValue: UUID()) }

}
