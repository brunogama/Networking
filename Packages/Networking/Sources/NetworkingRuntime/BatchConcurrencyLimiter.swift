import Foundation
import NetworkingCore

/// A cancellation-aware permit limiter for batch operations.
public actor BatchConcurrencyLimiter {
  private struct Waiter: Sendable {
    let id: UInt64
    let continuation: CheckedContinuation<Bool, Never>
  }

  private let maxConcurrency: Int?
  private var currentCount = 0
  private var nextWaiterID: UInt64 = 0
  private var waiters: [Waiter] = []

  /// Creates a limiter. A value of zero allows unlimited concurrency.
  public init(maxConcurrency: BatchConcurrencyLimit) {
    self.maxConcurrency = maxConcurrency.rawValue > 0 ? maxConcurrency.rawValue : nil
  }

  /// Acquires a permit, or returns `false` if cancellation wins while waiting.
  @discardableResult
  public func acquire() async -> Bool {
    guard !Task.isCancelled else { return false }
    guard let maxConcurrency else { return true }

    if currentCount < maxConcurrency {
      currentCount += 1
      return true
    }

    let waiterID = nextWaiterID
    nextWaiterID &+= 1

    let acquired = await enqueueWaiter(id: waiterID)

    if acquired, Task.isCancelled {
      release()
      return false
    }

    return acquired
  }

  /// Releases a permit to the first waiter, or makes it available to a future caller.
  public func release() {
    guard maxConcurrency != nil else { return }

    if let waiter = waiters.first {
      waiters.removeFirst()
      waiter.continuation.resume(returning: true)
    } else if currentCount > 0 {
      currentCount -= 1
    }
  }

  private func cancelWait(_ waiterID: UInt64) {
    guard let index = waiters.firstIndex(where: { $0.id == waiterID }) else { return }
    let waiter = waiters.remove(at: index)
    waiter.continuation.resume(returning: false)
  }

  private func enqueueWaiter(id waiterID: UInt64) async -> Bool {
    await withTaskCancellationHandler {
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
  }
}
