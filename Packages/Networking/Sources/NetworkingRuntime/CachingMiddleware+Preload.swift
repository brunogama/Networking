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
  private struct Waiter: Sendable {
    let id: UInt64
    let continuation: CheckedContinuation<Bool, Never>
  }

  private let maxCount: Int
  private var currentCount: Int
  private var nextWaiterID: UInt64 = 0
  private var waiters: [Waiter] = []

  public init(value: CachePreloadConcurrency) {
    let count = max(1, value.rawValue)
    self.maxCount = count
    self.currentCount = count
  }

  @discardableResult
  public func wait() async -> Bool {
    guard !Task.isCancelled else { return false }

    if currentCount > 0 {
      currentCount -= 1
      return true
    }

    let waiterID = nextWaiterID
    nextWaiterID &+= 1
    let acquired = await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        if Task.isCancelled {
          continuation.resume(returning: false)
        } else {
          waiters.append(Waiter(id: waiterID, continuation: continuation))
        }
      }
    } onCancel: {
      Task { await self.cancelWait(waiterID) }
    }

    if acquired, Task.isCancelled {
      signal()
      return false
    }

    return acquired
  }

  public func signal() {
    if let waiter = waiters.first {
      waiters.removeFirst()
      waiter.continuation.resume(returning: true)
    } else {
      currentCount = min(currentCount + 1, maxCount)
    }
  }

  private func cancelWait(_ waiterID: UInt64) {
    guard let index = waiters.firstIndex(where: { $0.id == waiterID }) else { return }
    let waiter = waiters.remove(at: index)
    waiter.continuation.resume(returning: false)
  }
}
