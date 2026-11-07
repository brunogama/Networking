import Foundation
import NetworkingCore

extension AdvancedMemoryCacheStorage {
  struct MemoryCacheEntry: Sendable {
    let cacheEntry: CachingMiddleware.CacheEntry
    var accessCount: Int = 0
    var lastAccessTime = Date()
    var tags: Set<CacheTagName> = []
    let storageSize: StorageSizeBytes

    func incrementAccess() -> Self {
      Self(
        cacheEntry: cacheEntry,
        accessCount: accessCount + 1,
        lastAccessTime: Date(),
        tags: tags,
        storageSize: storageSize
      )
    }
  }
}
