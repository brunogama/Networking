import NetworkingCore

/// Result of a caller-owned cache prefetch operation.
public enum WarmCacheResult: Sendable {
  /// Content was fetched successfully.
  case success(key: CacheKey, response: HTTPResponse)
  /// Fresh content was already present.
  case alreadyCached(key: CacheKey)
  /// Fetch, cancellation, or invalidation prevented publication.
  case failure(request: HTTPRequest, error: any Error)

  /// Whether usable content was already present or successfully fetched.
  public var isSuccess: CacheWarmSuccessFlag {
    switch self {
    case .success, .alreadyCached: return true
    case .failure: return false
    }
  }

  /// Stored key for success, or the failed request URL for diagnostic identification.
  public var cacheKey: CacheKey {
    switch self {
    case .success(let key, _), .alreadyCached(let key): return key
    case .failure(let request, _): return CacheKey(request.url.rawValue.absoluteString)
    }
  }
}
