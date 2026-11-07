import Foundation
import NetworkingCore
import NetworkingRuntime

/// An actor-owned in-memory cache that records lookups, writes, and invalidations.
///
/// Fresh lookups discard expired entries; revalidation can inspect their validators.
public actor MockCacheStorage: HTTPResponseCacheStorage, MockVerifiable {
  private var storage: [CacheKey: CachingMiddleware.CacheEntry] = [:]
  private var getCalls: [CacheKey] = []
  private var setCalls: [(key: CacheKey, entry: CachingMiddleware.CacheEntry)] = []
  private var removeCalls: [CacheKey] = []
  private var removeAllCallCount = 0
  private var removeExpiredCallCount = 0
  private var invalidationCallCount = 0

  /// Creates an empty cache with no recorded operations.
  public init() {}

  /// Returns the currently stored keys, including entries awaiting expiration cleanup.
  public func keys() -> [CacheKey] { Array(storage.keys) }

  /// Records a lookup and returns a fresh entry, discarding an expired entry.
  public func get(_ key: CacheKey) -> CachingMiddleware.CacheEntry? {
    getCalls.append(key)
    guard let entry = storage[key] else { return nil }
    guard !entry.isExpired.rawValue else {
      storage.removeValue(forKey: key)
      return nil
    }
    return entry
  }

  /// Records a lookup and returns an entry even when its freshness has expired.
  public func getForRevalidation(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    getCalls.append(key)
    return storage[key]
  }

  /// Records a write and replaces the stored entry and its tags atomically.
  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry) {
    setCalls.append((key, entry))
    storage[key] = entry
  }

  /// Records a removal and deletes the entry.
  public func remove(_ key: CacheKey) {
    removeCalls.append(key)
    storage.removeValue(forKey: key)
  }

  /// Records a clear and deletes all entries.
  public func removeAll() {
    removeAllCallCount += 1
    storage.removeAll()
  }

  /// Records expiration cleanup and deletes expired entries.
  public func removeExpired() {
    removeExpiredCallCount += 1
    let now = Date()
    storage = storage.filter { $0.value.expiresAt > now }
  }

  /// Records tag invalidation and removes entries associated with any supplied tag.
  public func removeByTags(_ tags: [CacheTagName]) {
    invalidationCallCount += 1
    let requested = Set(tags)
    storage = storage.filter { requested.isDisjoint(with: $0.value.tags) }
  }

  /// Records invalidation of whole keys matching a wildcard pattern.
  ///
  /// A star matches any substring; a question mark matches one character. Other text is literal.
  public func removeByPattern(_ pattern: CacheInvalidationPattern) {
    invalidationCallCount += 1
    guard let regex = cachePatternRegex(pattern) else { return }
    storage = storage.filter { key, _ in
      let range = NSRange(location: 0, length: key.rawValue.utf16.count)
      return regex.firstMatch(in: key.rawValue, range: range) == nil
    }
  }

  /// Records invalidation and removes the specified keys.
  public func removeByKeys(_ keys: [CacheKey]) {
    invalidationCallCount += 1
    for key in keys { storage.removeValue(forKey: key) }
  }

  /// Stores a test entry without recording a cache operation.
  public func stub(key: CacheKey, entry: CachingMiddleware.CacheEntry) { storage[key] = entry }

  /// Clears entries without recording a cache operation or clearing recorded calls.
  public func stubEmpty() { storage.removeAll() }

  /// Total recorded operations, read in one actor turn.
  public var callCount: MockVerificationCount {
    MockVerificationCount(
      getCalls.count + setCalls.count + removeCalls.count
        + removeAllCallCount + removeExpiredCallCount + invalidationCallCount
    )
  }

  /// Requires the specified number of fresh or revalidation lookups for a key.
  public func verifyGet(_ key: CacheKey, times: MockVerificationCount = 1) throws(MockError) {
    try verify(actual: getCalls.filter { $0 == key }.count, expected: times)
  }

  /// Requires the specified number of writes for a key.
  public func verifySet(_ key: CacheKey, times: MockVerificationCount = 1) throws(MockError) {
    try verify(actual: setCalls.filter { $0.key == key }.count, expected: times)
  }

  /// Requires the specified number of individual removals for a key.
  public func verifyRemove(_ key: CacheKey, times: MockVerificationCount = 1) throws(MockError) {
    try verify(actual: removeCalls.filter { $0 == key }.count, expected: times)
  }

  /// Requires the specified number of complete cache clears.
  public func verifyRemoveAll(times: MockVerificationCount = 1) throws(MockError) {
    try verify(actual: removeAllCallCount, expected: times)
  }

  /// Requires the specified number of expiration cleanup operations.
  public func verifyRemoveExpired(times: MockVerificationCount = 1) throws(MockError) {
    try verify(actual: removeExpiredCallCount, expected: times)
  }

  private func verify(actual: Int, expected: MockVerificationCount) throws(MockError) {
    guard MockVerificationCount(actual) == expected else {
      throw .unexpectedCallCount(expected: expected, actual: MockVerificationCount(actual))
    }
  }

  /// Returns the retained keys without recording an operation.
  public func getStoredKeys() -> [CacheKey] { keys() }

  /// Returns the number of retained entries without recording an operation.
  public func getStorageCount() -> CacheEntryCount { CacheEntryCount(storage.count) }

  /// Returns fresh and revalidation lookup keys in call order.
  public func getGetCalls() -> [CacheKey] { getCalls }

  /// Returns recorded writes in call order.
  public func getSetCalls() -> [(key: CacheKey, entry: CachingMiddleware.CacheEntry)] { setCalls }

  /// Returns recorded individual removals in call order.
  public func getRemoveCalls() -> [CacheKey] { removeCalls }

  /// Clears entries and all recorded operations in one actor turn.
  public func reset() {
    storage.removeAll()
    getCalls.removeAll()
    setCalls.removeAll()
    removeCalls.removeAll()
    removeAllCallCount = 0
    removeExpiredCallCount = 0
    invalidationCallCount = 0
  }
}
