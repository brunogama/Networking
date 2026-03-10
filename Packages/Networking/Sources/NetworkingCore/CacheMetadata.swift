import Foundation

/// Cache configuration metadata extracted from method attributes.
public struct CacheMetadata: Sendable {
  public let ttl: TimeInterval?
  public let tags: [String]
  public let customKey: String?
  public let isInvalidating: Bool
  public let invalidationTags: [String]
  public let invalidationPattern: String?
  public let invalidationKeys: [String]

  public init(
    ttl: TimeInterval? = nil,
    tags: [String] = [],
    customKey: String? = nil,
    isInvalidating: Bool = false,
    invalidationTags: [String] = [],
    invalidationPattern: String? = nil,
    invalidationKeys: [String] = []
  ) {
    self.ttl = ttl
    self.tags = tags
    self.customKey = customKey
    self.isInvalidating = isInvalidating
    self.invalidationTags = invalidationTags
    self.invalidationPattern = invalidationPattern
    self.invalidationKeys = invalidationKeys
  }
}
