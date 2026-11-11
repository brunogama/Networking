import Foundation
import NetworkingCore

extension CachingMiddleware {
}

extension HTTPResponseCacheStorage {

  public func getForRevalidation(_ key: CacheKey) async -> CachingMiddleware.CacheEntry? {
    await get(key)
  }
}

extension HTTPHeaders {
  func caseInsensitiveValue(for name: String) -> HTTPHeaderValue? {
    first { $0.key.rawValue.caseInsensitiveCompare(name) == .orderedSame }?.value
  }
}
