import NetworkingRuntime
import NetworkingInterceptorsCompat
import NetworkingObservability
import NetworkingCore
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Mock implementation of CachingMiddleware.CacheStorage for testing cache behavior
///
/// Provides in-memory storage with call tracking and verification capabilities.
/// Uses actor isolation for thread safety (no @unchecked Sendable required).
///
/// ## Usage Example
/// ```swift
/// let mockStorage = MockCacheStorage()
///
/// // Stub cache entry
/// let entry = CachingMiddleware.CacheEntry(
///   response: HTTPResponse(status: .ok),
///   ttl: 300
/// )
/// await mockStorage.stub(key: "test-key", entry: entry)
///
/// // Retrieve and verify
/// let cached = await mockStorage.get("test-key")
/// #expect(cached != nil)
/// try await mockStorage.verifyGet("test-key", times: 1)
/// ```
///
/// - Note: Actor isolation provides built-in thread safety (Sendable by design)
public actor MockCacheStorage: CachingMiddleware.CacheStorage, MockVerifiable {
  // MARK: - State

  private var storage: [CacheKey: CachingMiddleware.CacheEntry] = [:]
  private var getCalls: [CacheKey] = []
  private var setCalls: [(key: CacheKey, entry: CachingMiddleware.CacheEntry)] = []
  private var removeCalls: [CacheKey] = []
  private var removeAllCallCount: Int = 0
  private var removeExpiredCallCount: Int = 0
  private var removeByTagsCalls: [[CacheTagName]] = []
  private var removeByPatternCalls: [CacheInvalidationPattern] = []
  private var removeByKeysCalls: [[CacheKey]] = []

  // MARK: - Initialization

  public init() {}

  // MARK: - CacheStorage Conformance

  public func get(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    getCalls.append(key)
    return storage[key]
  }

  public func set(_ key: CacheKey, entry: CachingMiddleware.CacheEntry) async {
    setCalls.append((key: key, entry: entry))
    storage[key] = entry
  }

  public func remove(_ key: CacheKey) async {
    removeCalls.append(key)
    storage.removeValue(forKey: key)
  }

  public func removeAll() async {
    removeAllCallCount += 1
    storage.removeAll()
  }

  public func removeExpired() async {
    removeExpiredCallCount += 1
    let now = Date()
    storage = storage.filter { _, entry in
      now <= entry.expiresAt
    }
  }

  public func removeByTags(_ tags: [CacheTagName]) async {
    removeByTagsCalls.append(tags)
    // Note: Basic mock doesn't track tag metadata
    // In real implementation, would filter by tags
  }

  public func removeByPattern(_ pattern: CacheInvalidationPattern) async {
    removeByPatternCalls.append(pattern)
    // Simple pattern matching
    let regex: NSRegularExpression?
    do {
      let regexPattern =
        pattern.rawValue
        .replacingOccurrences(of: "*", with: ".*")
        .replacingOccurrences(of: "?", with: ".")
      regex = try NSRegularExpression(pattern: regexPattern, options: [])
    } catch {
      return
    }

    guard let regex = regex else { return }

    let keysToRemove = storage.keys.filter { key in
      let range = NSRange(location: 0, length: key.rawValue.utf16.count)
      return regex.firstMatch(in: key.rawValue, options: [], range: range) != nil
    }

    for key in keysToRemove {
      storage.removeValue(forKey: key)
    }
  }

  public func removeByKeys(_ keys: [CacheKey]) async {
    removeByKeysCalls.append(keys)
    for key in keys {
      storage.removeValue(forKey: key)
    }
  }

  // MARK: - Stubbing Methods

  /// Stub a cache entry for testing
  ///
  /// - Parameters:
  ///   - key: Cache key
  ///   - entry: Cache entry to store
  public func stub(key: CacheKey, entry: CachingMiddleware.CacheEntry) {
    storage[key] = entry
  }

  /// Clear all storage (reset to empty state)
  public func stubEmpty() {
    storage.removeAll()
  }

  // MARK: - MockVerifiable Conformance

  /// Total number of calls across all operations
  ///
  /// - Note: nonisolated to allow synchronous access from test assertions
  nonisolated public var callCount: MockVerificationCount {
    get async {
      MockVerificationCount(
        await getCalls.count
          + setCalls.count
          + removeCalls.count
          + removeAllCallCount
          + removeExpiredCallCount
          + removeByTagsCalls.count
          + removeByPatternCalls.count
          + removeByKeysCalls.count
      )
    }
  }

  // MARK: - Verification Methods

  /// Verify get was called specific number of times for a key
  ///
  /// - Parameters:
  ///   - key: Cache key to verify
  ///   - times: Expected number of calls
  /// - Throws: MockError if call count doesn't match
  public func verifyGet(
    _ key: CacheKey,
    times: MockVerificationCount = MockVerificationCount(rawValue: 1)
  ) throws {
    let actualCount = MockVerificationCount(getCalls.filter { $0 == key }.count)
    guard actualCount == times else {
      throw MockError.unexpectedCallCount(
        expected: times,
        actual: actualCount
      )
    }
  }

  /// Verify set was called specific number of times for a key
  ///
  /// - Parameters:
  ///   - key: Cache key to verify
  ///   - times: Expected number of calls
  /// - Throws: MockError if call count doesn't match
  public func verifySet(
    _ key: CacheKey,
    times: MockVerificationCount = MockVerificationCount(rawValue: 1)
  ) throws {
    let actualCount = MockVerificationCount(setCalls.filter { $0.key == key }.count)
    guard actualCount == times else {
      throw MockError.unexpectedCallCount(
        expected: times,
        actual: actualCount
      )
    }
  }

  /// Verify remove was called specific number of times for a key
  ///
  /// - Parameters:
  ///   - key: Cache key to verify
  ///   - times: Expected number of calls
  /// - Throws: MockError if call count doesn't match
  public func verifyRemove(
    _ key: CacheKey,
    times: MockVerificationCount = MockVerificationCount(rawValue: 1)
  ) throws {
    let actualCount = MockVerificationCount(removeCalls.filter { $0 == key }.count)
    guard actualCount == times else {
      throw MockError.unexpectedCallCount(
        expected: times,
        actual: actualCount
      )
    }
  }

  /// Verify removeAll was called specific number of times
  ///
  /// - Parameter times: Expected number of calls
  /// - Throws: MockError if call count doesn't match
  public func verifyRemoveAll(
    times: MockVerificationCount = MockVerificationCount(rawValue: 1)
  ) throws {
    let actualCount = MockVerificationCount(removeAllCallCount)
    guard actualCount == times else {
      throw MockError.unexpectedCallCount(
        expected: times,
        actual: actualCount
      )
    }
  }

  /// Verify removeExpired was called specific number of times
  ///
  /// - Parameter times: Expected number of calls
  /// - Throws: MockError if call count doesn't match
  public func verifyRemoveExpired(
    times: MockVerificationCount = MockVerificationCount(rawValue: 1)
  ) throws {
    let actualCount = MockVerificationCount(removeExpiredCallCount)
    guard actualCount == times else {
      throw MockError.unexpectedCallCount(
        expected: times,
        actual: actualCount
      )
    }
  }

  // MARK: - Inspection Methods

  /// Get all currently stored keys
  ///
  /// - Returns: Array of cache keys currently in storage
  public func getStoredKeys() -> [CacheKey] {
    Array(storage.keys)
  }

  /// Get the number of entries currently stored
  ///
  /// - Returns: Number of cache entries
  public func getStorageCount() -> CacheEntryCount {
    CacheEntryCount(storage.count)
  }

  /// Get all get call history
  ///
  /// - Returns: Array of keys that were requested via get()
  public func getGetCalls() -> [CacheKey] {
    getCalls
  }

  /// Get all set call history
  ///
  /// - Returns: Array of tuples with keys and entries that were set
  public func getSetCalls() -> [(key: CacheKey, entry: CachingMiddleware.CacheEntry)] {
    setCalls
  }

  /// Get all remove call history
  ///
  /// - Returns: Array of keys that were removed via remove()
  public func getRemoveCalls() -> [CacheKey] {
    removeCalls
  }

  /// Reset all state (storage, call counts, call history)
  public func reset() {
    storage.removeAll()
    getCalls.removeAll()
    setCalls.removeAll()
    removeCalls.removeAll()
    removeAllCallCount = 0
    removeExpiredCallCount = 0
    removeByTagsCalls.removeAll()
    removeByPatternCalls.removeAll()
    removeByKeysCalls.removeAll()
  }
}
