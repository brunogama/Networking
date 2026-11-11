import NetworkingCore

/// Cache size management strategies.
public enum CacheSizePolicy: Sendable {

  case maxEntries(CacheEntryLimit)

  case maxMemory(StorageSizeBytes)

  case maxDiskSize(StorageSizeBytes)

  case combined(entries: CacheEntryLimit, memory: StorageSizeBytes)
}
