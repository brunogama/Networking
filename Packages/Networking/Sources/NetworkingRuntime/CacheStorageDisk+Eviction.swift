import Foundation
import NetworkingCore

extension DiskCacheStorage {
  var currentDiskUsage: StorageSizeBytes {
    metadata.values.reduce(0) { $0 + $1.dataSize }
  }

  func enforceSize() {
    switch sizePolicy {
    case .maxEntries(let limit), .combined(let limit, _):
      enforceEntryLimit(limit)
    case .maxDiskSize(let limit):
      enforceByteLimit(limit)
    case .maxMemory:
      break
    }
  }

  private func enforceEntryLimit(_ limit: CacheEntryLimit) {
    while metadata.count > limit.rawValue {
      guard evictOldest() else { break }
    }
  }

  private func enforceByteLimit(_ limit: StorageSizeBytes) {
    while currentDiskUsage > limit {
      guard evictOldest() else { break }
    }
  }

  private func evictOldest() -> Bool {
    guard let oldest = metadata.min(by: { $0.value.cachedAt < $1.value.cachedAt })?.key else {
      return false
    }
    deleteEntry(oldest)
    return true
  }
}
