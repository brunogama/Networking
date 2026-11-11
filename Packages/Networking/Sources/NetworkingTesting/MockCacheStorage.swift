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

  public init() {}

  public func keys() -> [CacheKey] { Array(storage.keys) }

  public func get(_ key: CacheKey) -> CachingMiddleware.CacheEntry? {
    getCalls.append(key)
    guard let entry = storage[key] else { return nil }
    guard !entry.isExpired.rawValue else {
      storage.removeValue(forKey: key)
      return nil
    }
    return entry
  }

  public func getForRevalidation(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    getCalls.append(key)
    return storage[key]
  }

  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry) {
    setCalls.append((key, entry))
    storage[key] = entry
  }

  public func remove(_ key: CacheKey) {
    removeCalls.append(key)
    storage.removeValue(forKey: key)
  }

  public func removeAll() {
    removeAllCallCount += 1
    storage.removeAll()
  }

  public func removeExpired() {
    removeExpiredCallCount += 1
    let now = Date()
    storage = storage.filter { $0.value.expiresAt > now }
  }

  public func removeByTags(_ tags: [CacheTagName]) {
    invalidationCallCount += 1
    let requested = Set(tags)
    storage = storage.filter { requested.isDisjoint(with: $0.value.tags) }
  }

  public func removeByPattern(_ pattern: CacheInvalidationPattern) {
    invalidationCallCount += 1
    guard let regex = cachePatternRegex(pattern) else { return }
    storage = storage.filter { key, _ in
      let range = NSRange(location: 0, length: key.rawValue.utf16.count)
      return regex.firstMatch(in: key.rawValue, range: range) == nil
    }
  }

  public func removeByKeys(_ keys: [CacheKey]) {
    invalidationCallCount += 1
    for key in keys { storage.removeValue(forKey: key) }
  }

  public func stub(key: CacheKey, entry: CachingMiddleware.CacheEntry) { storage[key] = entry }

  public func stubEmpty() { storage.removeAll() }

  public var callCount: MockVerificationCount {
    MockVerificationCount(
      getCalls.count + setCalls.count + removeCalls.count
        + removeAllCallCount + removeExpiredCallCount + invalidationCallCount
    )
  }

  public func verifyGet(_ key: CacheKey, times: MockVerificationCount = 1) throws(MockError) {
    try verify(actual: getCalls.filter { $0 == key }.count, expected: times)
  }

  public func verifySet(_ key: CacheKey, times: MockVerificationCount = 1) throws(MockError) {
    try verify(actual: setCalls.filter { $0.key == key }.count, expected: times)
  }

  public func verifyRemove(_ key: CacheKey, times: MockVerificationCount = 1) throws(MockError) {
    try verify(actual: removeCalls.filter { $0 == key }.count, expected: times)
  }

  public func verifyRemoveAll(times: MockVerificationCount = 1) throws(MockError) {
    try verify(actual: removeAllCallCount, expected: times)
  }

  public func verifyRemoveExpired(times: MockVerificationCount = 1) throws(MockError) {
    try verify(actual: removeExpiredCallCount, expected: times)
  }

  private func verify(actual: Int, expected: MockVerificationCount) throws(MockError) {
    guard MockVerificationCount(actual) == expected else {
      throw .unexpectedCallCount(expected: expected, actual: MockVerificationCount(actual))
    }
  }

  public func getStoredKeys() -> [CacheKey] { keys() }

  public func getStorageCount() -> CacheEntryCount { CacheEntryCount(storage.count) }

  public func getGetCalls() -> [CacheKey] { getCalls }

  public func getSetCalls() -> [(key: CacheKey, entry: CachingMiddleware.CacheEntry)] { setCalls }

  public func getRemoveCalls() -> [CacheKey] { removeCalls }

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
