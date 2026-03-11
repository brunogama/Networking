// swiftlint:disable file_length
import Foundation
#if canImport(CoreFoundation)
import CoreFoundation
#endif

public struct BoundaryString<Tag>: Sendable, Hashable, Codable, Comparable,
  CustomStringConvertible, CustomDebugStringConvertible
{
  private let storage: String

  public init(rawValue: String) {
    storage = rawValue
  }

  package init(_ rawValue: String) {
    self.init(rawValue: rawValue)
  }

  package var rawValue: String {
    storage
  }

  public var isEmpty: BoundaryStringEmptyFlag<Tag> {
    BoundaryStringEmptyFlag(rawValue.isEmpty)
  }

  package func contains<S: StringProtocol>(_ other: S) -> Bool {
    rawValue.contains(other)
  }

  package func lowercased() -> String {
    rawValue.lowercased()
  }

  package func uppercased() -> String {
    rawValue.uppercased()
  }

  package var utf8: String.UTF8View {
    rawValue.utf8
  }

  public func caseInsensitiveCompare(_ other: Self) -> ComparisonResult {
    rawValue.caseInsensitiveCompare(other.rawValue)
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public var description: String {
    rawValue
  }

  public var debugDescription: String {
    rawValue
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(rawValue: try container.decode(String.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension BoundaryString: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
  public init(stringLiteral value: StringLiteralType) {
    self.init(rawValue: value)
  }

  public init(stringInterpolation: String.StringInterpolation) {
    // swiftlint:disable:next compiler_protocol_init
    self.init(rawValue: String(stringInterpolation: stringInterpolation))
  }
}

public struct BoundaryInt<Tag>: Sendable, Hashable, Codable,
  Comparable, CustomStringConvertible, CustomDebugStringConvertible
{
  private let storage: Int

  public init(rawValue: Int) {
    storage = rawValue
  }

  package init(_ rawValue: Int) {
    self.init(rawValue: rawValue)
  }

  package var rawValue: Int {
    storage
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public static func + (lhs: Self, rhs: Self) -> Self {
    Self(lhs.rawValue + rhs.rawValue)
  }

  public static func - (lhs: Self, rhs: Self) -> Self {
    Self(lhs.rawValue - rhs.rawValue)
  }

  public var description: String {
    String(rawValue)
  }

  public var debugDescription: String {
    description
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(rawValue: try container.decode(Int.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension BoundaryInt: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: IntegerLiteralType) {
    self.init(rawValue: value)
  }
}

public struct BoundaryInt64<Tag>: Sendable, Hashable, Codable,
  Comparable, CustomStringConvertible, CustomDebugStringConvertible
{
  private let storage: Int64

  public init(rawValue: Int64) {
    storage = rawValue
  }

  package init(_ rawValue: Int64) {
    self.init(rawValue: rawValue)
  }

  package var rawValue: Int64 {
    storage
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public static func + (lhs: Self, rhs: Self) -> Self {
    Self(lhs.rawValue + rhs.rawValue)
  }

  public static func - (lhs: Self, rhs: Self) -> Self {
    Self(lhs.rawValue - rhs.rawValue)
  }

  public var description: String {
    String(rawValue)
  }

  public var debugDescription: String {
    description
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(rawValue: try container.decode(Int64.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension BoundaryInt64: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: IntegerLiteralType) {
    self.init(rawValue: Int64(value))
  }
}

public struct BoundaryDouble<Tag>: Sendable, Hashable, Codable, Comparable, CustomStringConvertible,
  CustomDebugStringConvertible
{
  private let storage: Double

  public init(rawValue: Double) {
    storage = rawValue
  }

  package init(_ rawValue: Double) {
    self.init(rawValue: rawValue)
  }

  package var rawValue: Double {
    storage
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public static func + (lhs: Self, rhs: Self) -> Self {
    Self(lhs.rawValue + rhs.rawValue)
  }

  public static func - (lhs: Self, rhs: Self) -> Self {
    Self(lhs.rawValue - rhs.rawValue)
  }

  public var description: String {
    String(rawValue)
  }

  public var debugDescription: String {
    description
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(rawValue: try container.decode(Double.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension BoundaryDouble: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
  public init(floatLiteral value: FloatLiteralType) {
    self.init(rawValue: value)
  }

  public init(integerLiteral value: IntegerLiteralType) {
    self.init(rawValue: Double(value))
  }
}

public struct BoundaryBool<Tag>: Sendable, Hashable, Codable,
  CustomStringConvertible, CustomDebugStringConvertible
{
  private let storage: Bool

  public init(rawValue: Bool) {
    storage = rawValue
  }

  package init(_ rawValue: Bool) {
    self.init(rawValue: rawValue)
  }

  package var rawValue: Bool {
    storage
  }

  public var description: String {
    String(rawValue)
  }

  public var debugDescription: String {
    description
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(rawValue: try container.decode(Bool.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension BoundaryBool: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: BooleanLiteralType) {
    self.init(rawValue: value)
  }
}

public struct BoundaryData<Tag>: Sendable, Hashable, Codable {
  private let storage: Data

  package init(rawValue: Data) {
    storage = rawValue
  }

  public init<Bytes: ContiguousBytes>(_ rawValue: Bytes) {
    storage = rawValue.withUnsafeBytes { Data($0) }
  }

  package var rawValue: Data {
    storage
  }

  public var count: BoundaryDataCount<Tag> {
    BoundaryDataCount(rawValue.count)
  }

  public var isEmpty: BoundaryDataEmptyFlag<Tag> {
    BoundaryDataEmptyFlag(rawValue.isEmpty)
  }

  package func write(to url: URL) throws {
    try rawValue.write(to: url)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(rawValue: try container.decode(Data.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

public struct BoundaryURL<Tag>: Sendable, Hashable, Codable,
  CustomStringConvertible, CustomDebugStringConvertible
{
  private let storage: URL

  package init(rawValue: URL) {
    storage = rawValue
  }

  package init(_ rawValue: URL) {
    self.init(rawValue: rawValue)
  }

  public init?<TextTag>(_ rawValue: BoundaryString<TextTag>) {
    self.init(string: rawValue.description)
  }

  package init?(string: String) {
    guard let url = URL(string: string) else {
      return nil
    }
    self.init(rawValue: url)
  }

  package var rawValue: URL {
    storage
  }

  package var absoluteString: String {
    rawValue.absoluteString
  }

  package var host: String? {
    rawValue.host
  }

  package var path: String {
    rawValue.path
  }

  package func appendingPathComponent(_ pathComponent: String) -> Self {
    Self(rawValue.appendingPathComponent(pathComponent))
  }

  package var scheme: String? {
    rawValue.scheme
  }

  package var port: Int? {
    rawValue.port
  }

  package var isFileURL: Bool {
    rawValue.isFileURL
  }

  package var lastPathComponent: String {
    rawValue.lastPathComponent
  }

  package var pathComponents: [String] {
    rawValue.pathComponents
  }

  package var standardizedFileURL: Self {
    Self(rawValue.standardizedFileURL)
  }

  package var deletingLastPathComponent: Self {
    Self(rawValue.deletingLastPathComponent())
  }

  public var description: String {
    rawValue.absoluteString
  }

  public var debugDescription: String {
    description
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(rawValue: try container.decode(URL.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

public struct BoundaryUUID<Tag>: Sendable, Hashable, Codable,
  CustomStringConvertible, CustomDebugStringConvertible
{
  private let storage: UUID

  package init(rawValue: UUID) {
    storage = rawValue
  }

  package init(_ rawValue: UUID) {
    self.init(rawValue: rawValue)
  }

  public init() {
    self.init(rawValue: UUID())
  }

  package var rawValue: UUID {
    storage
  }

  package var uuidString: String {
    rawValue.uuidString
  }

  public var description: String {
    rawValue.uuidString
  }

  public var debugDescription: String {
    description
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(rawValue: try container.decode(UUID.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

public struct BoundaryDuration<Tag>: Sendable, Hashable, Codable,
  Comparable, CustomStringConvertible,
  CustomDebugStringConvertible
{
  private let storage: TimeInterval

  public init(rawValue: TimeInterval) {
    storage = rawValue
  }

  package init(_ rawValue: TimeInterval) {
    self.init(rawValue: rawValue)
  }

  package var rawValue: TimeInterval {
    storage
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public static func + (lhs: Self, rhs: Self) -> Self {
    Self(lhs.rawValue + rhs.rawValue)
  }

  public static func - (lhs: Self, rhs: Self) -> Self {
    Self(lhs.rawValue - rhs.rawValue)
  }

  package static func * (lhs: Self, rhs: Double) -> Self {
    Self(lhs.rawValue * rhs)
  }

  public var description: String {
    String(rawValue)
  }

  public var debugDescription: String {
    description
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(rawValue: try container.decode(TimeInterval.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension BoundaryDuration: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
  public init(floatLiteral value: FloatLiteralType) {
    self.init(rawValue: value)
  }

  public init(integerLiteral value: IntegerLiteralType) {
    self.init(rawValue: Double(value))
  }
}

public struct BoundaryStringEmptyFlagTag<WrappedTag>: Sendable {}
public typealias BoundaryStringEmptyFlag<WrappedTag> = BoundaryBool<
  BoundaryStringEmptyFlagTag<WrappedTag>
>

public struct BoundaryDataCountTag<WrappedTag>: Sendable {}
public typealias BoundaryDataCount<WrappedTag> = BoundaryInt<BoundaryDataCountTag<WrappedTag>>

public struct BoundaryDataEmptyFlagTag<WrappedTag>: Sendable {}
public typealias BoundaryDataEmptyFlag<WrappedTag> = BoundaryBool<
  BoundaryDataEmptyFlagTag<WrappedTag>
>

public enum HTTPHeaderCollectionEmptyFlagTag: Sendable {}
public typealias HTTPHeaderCollectionEmptyFlag = BoundaryBool<HTTPHeaderCollectionEmptyFlagTag>

public enum HTTPHeaderCollectionCountTag: Sendable {}
public typealias HTTPHeaderCollectionCount = BoundaryInt<HTTPHeaderCollectionCountTag>
