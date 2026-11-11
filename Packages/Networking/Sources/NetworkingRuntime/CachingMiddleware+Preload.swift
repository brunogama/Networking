import NetworkingCore

/// Result of a caller-owned cache prefetch operation.
public enum WarmCacheResult: Sendable {

  case success(key: CacheKey, response: HTTPResponse)

  case alreadyCached(key: CacheKey)

  case failure(request: HTTPRequest, error: any Error)

  public var isSuccess: CacheWarmSuccessFlag {
    switch self {
    case .success, .alreadyCached: return true
    case .failure: return false
    }
  }

  public var cacheKey: CacheKey {
    switch self {
    case .success(let key, _), .alreadyCached(let key): return key
    case .failure(let request, _): return CacheKey(request.url.rawValue.absoluteString)
    }
  }
}
