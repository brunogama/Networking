import Foundation
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

enum PersistentCacheKind: CaseIterable, Sendable {
  case disk
  case hybrid

  func storage(directory: URL) throws -> any HTTPResponseCacheStorage {
    switch self {
    case .disk:
      return try DiskCacheStorage(cacheDirectory: CacheDirectoryURL(directory))
    case .hybrid:
      return try HybridCacheStorage(cacheDirectory: CacheDirectoryURL(directory))
    }
  }
}
