import Foundation
import NetworkingCore

/// Result of a cache warming operation
public enum WarmCacheResult: Sendable {
  case success(key: CacheKey, response: HTTPResponse)
  case alreadyCached(key: CacheKey)
  case failure(request: HTTPRequest, error: any Error)

  public var isSuccess: CacheWarmSuccessFlag {
    switch self {
    case .success, .alreadyCached:
      return true

    case .failure:
      return false
    }
  }

  public var cacheKey: CacheKey {
    switch self {
    case .success(let key, _), .alreadyCached(let key):
      return key

    case .failure(let request, _):
      return CacheKey(request.url.absoluteString)
    }
  }
}

/// Strategy for preloading cache entries
public enum CachePreloadStrategy: Sendable {
  case sequential
  case concurrent(maxConcurrency: CachePreloadConcurrency)
  case prioritized
}

/// Pattern for cache preloading
public struct CachePreloadPattern: Sendable {
  public let name: CachePatternName
  public let priority: CachePreloadPriority
  public let concurrency: CachePreloadConcurrency
  public let requestGenerator: @Sendable () -> [HTTPRequest]

  public init(
    name: CachePatternName,
    priority: CachePreloadPriority = 0,
    concurrency: CachePreloadConcurrency = 2,
    requestGenerator: @escaping @Sendable () -> [HTTPRequest]
  ) {
    self.name = name
    self.priority = priority
    self.concurrency = concurrency
    self.requestGenerator = requestGenerator
  }

  public func generateRequests() -> [HTTPRequest] {
    requestGenerator()
  }
}

/// Simple async semaphore for controlling concurrency
public actor AsyncSemaphore {
  private let maxCount: CachePreloadConcurrency
  private var currentCount: CachePreloadConcurrency
  private var waiters: [CheckedContinuation<Void, Never>] = []

  public init(value: CachePreloadConcurrency) {
    self.maxCount = value
    self.currentCount = value
  }

  public func wait() async {
    if currentCount > 0 {
      currentCount = CachePreloadConcurrency(currentCount.rawValue - 1)
    } else {
      await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
          // Check cancellation before storing
          if Task.isCancelled {
            continuation.resume()
            return
          }
          waiters.append(continuation)
        }
      } onCancel: {
        Task {
          await self.cancelWait()
        }
      }
    }
  }

  public func signal() {
    if let waiter = waiters.first {
      waiters.removeFirst()
      waiter.resume()
    } else {
      currentCount = min(currentCount + 1, maxCount)
    }
  }

  /// Cancels a waiting continuation when task is cancelled
  private func cancelWait() {
    // When cancelled, we need to release one waiter if any are waiting
    // This ensures the continuation stored before cancellation is resumed
    if !waiters.isEmpty {
      let waiter = waiters.removeFirst()
      waiter.resume()
    }
  }
}
