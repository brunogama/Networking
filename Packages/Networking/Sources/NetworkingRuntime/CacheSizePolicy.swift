import NetworkingCore

/// Cache size management strategies.
public enum CacheSizePolicy: Sendable {
  /// Maximum number of entries
  case maxEntries(CacheEntryLimit)
  /// Maximum memory usage in bytes
  case maxMemory(StorageSizeBytes)
  /// Maximum disk usage in bytes
  case maxDiskSize(StorageSizeBytes)
  /// Combined entry and memory limits
  case combined(entries: CacheEntryLimit, memory: StorageSizeBytes)
}
