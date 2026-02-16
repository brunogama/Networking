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

  private var storage: [String: CachingMiddleware.CacheEntry] = [:]
  private var getCalls: [String] = []
  private var setCalls: [(key: String, entry: CachingMiddleware.CacheEntry)] = []
  private var removeCalls: [String] = []
  private var removeAllCallCount: Int = 0
  private var removeExpiredCallCount: Int = 0
  private var removeByTagsCalls: [[String]] = []
  private var removeByPatternCalls: [String] = []
  private var removeByKeysCalls: [[String]] = []

  // MARK: - Initialization

  public init() {}

  // MARK: - CacheStorage Conformance

  public func get(_ key: String) async -> CachingMiddleware.CacheEntry? {
    getCalls.append(key)
    return storage[key]
  }

  public func set(_ key: String, entry: CachingMiddleware.CacheEntry) async {
    setCalls.append((key: key, entry: entry))
    storage[key] = entry
  }

  public func remove(_ key: String) async {
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

  public func removeByTags(_ tags: [String]) async {
    removeByTagsCalls.append(tags)
    // Note: Basic mock doesn't track tag metadata
    // In real implementation, would filter by tags
  }

  public func removeByPattern(_ pattern: String) async {
    removeByPatternCalls.append(pattern)
    // Simple pattern matching
    let regex: NSRegularExpression?
    do {
      let regexPattern =
        pattern
        .replacingOccurrences(of: "*", with: ".*")
        .replacingOccurrences(of: "?", with: ".")
      regex = try NSRegularExpression(pattern: regexPattern, options: [])
    } catch {
      return
    }

    guard let regex = regex else { return }

    let keysToRemove = storage.keys.filter { key in
      let range = NSRange(location: 0, length: key.utf16.count)
      return regex.firstMatch(in: key, options: [], range: range) != nil
    }

    for key in keysToRemove {
      storage.removeValue(forKey: key)
    }
  }

  public func removeByKeys(_ keys: [String]) async {
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
  public func stub(key: String, entry: CachingMiddleware.CacheEntry) {
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
  nonisolated public var callCount: Int {
    get async {
      await getCalls.count
        + setCalls.count
        + removeCalls.count
        + removeAllCallCount
        + removeExpiredCallCount
        + removeByTagsCalls.count
        + removeByPatternCalls.count
        + removeByKeysCalls.count
    }
  }

  // MARK: - Verification Methods

  /// Verify get was called specific number of times for a key
  ///
  /// - Parameters:
  ///   - key: Cache key to verify
  ///   - times: Expected number of calls
  /// - Throws: MockError if call count doesn't match
  public func verifyGet(_ key: String, times: Int = 1) throws {
    let actualCount = getCalls.filter { $0 == key }.count
    guard actualCount == times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actualCount)
    }
  }

  /// Verify set was called specific number of times for a key
  ///
  /// - Parameters:
  ///   - key: Cache key to verify
  ///   - times: Expected number of calls
  /// - Throws: MockError if call count doesn't match
  public func verifySet(_ key: String, times: Int = 1) throws {
    let actualCount = setCalls.filter { $0.key == key }.count
    guard actualCount == times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actualCount)
    }
  }

  /// Verify remove was called specific number of times for a key
  ///
  /// - Parameters:
  ///   - key: Cache key to verify
  ///   - times: Expected number of calls
  /// - Throws: MockError if call count doesn't match
  public func verifyRemove(_ key: String, times: Int = 1) throws {
    let actualCount = removeCalls.filter { $0 == key }.count
    guard actualCount == times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actualCount)
    }
  }

  /// Verify removeAll was called specific number of times
  ///
  /// - Parameter times: Expected number of calls
  /// - Throws: MockError if call count doesn't match
  public func verifyRemoveAll(times: Int = 1) throws {
    guard removeAllCallCount == times else {
      throw MockError.unexpectedCallCount(expected: times, actual: removeAllCallCount)
    }
  }

  /// Verify removeExpired was called specific number of times
  ///
  /// - Parameter times: Expected number of calls
  /// - Throws: MockError if call count doesn't match
  public func verifyRemoveExpired(times: Int = 1) throws {
    guard removeExpiredCallCount == times else {
      throw MockError.unexpectedCallCount(expected: times, actual: removeExpiredCallCount)
    }
  }

  // MARK: - Inspection Methods

  /// Get all currently stored keys
  ///
  /// - Returns: Array of cache keys currently in storage
  public func getStoredKeys() -> [String] {
    Array(storage.keys)
  }

  /// Get the number of entries currently stored
  ///
  /// - Returns: Number of cache entries
  public func getStorageCount() -> Int {
    storage.count
  }

  /// Get all get call history
  ///
  /// - Returns: Array of keys that were requested via get()
  public func getGetCalls() -> [String] {
    getCalls
  }

  /// Get all set call history
  ///
  /// - Returns: Array of tuples with keys and entries that were set
  public func getSetCalls() -> [(key: String, entry: CachingMiddleware.CacheEntry)] {
    setCalls
  }

  /// Get all remove call history
  ///
  /// - Returns: Array of keys that were removed via remove()
  public func getRemoveCalls() -> [String] {
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
