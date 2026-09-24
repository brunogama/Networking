import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

package struct NetworkTrafficDelegateSnapshot: Sendable {
  package let redirects: [NetworkTrafficRedirect]
  package let taskInterval: DateInterval?
  package let transactions: [NetworkTrafficTransaction]
  package let receivedMetrics: Bool
}

// URLSession already owns the forwarded delegate and delivers its callbacks on the
// delegate queue. This adapter never mutates that delegate; its own mutable state
// is protected by lock and snapshots copy only Sendable values.
package final class NetworkTrafficTaskDelegate: NSObject, URLSessionTaskDelegate,
  @unchecked Sendable
{
  private struct State {
    var redirects: [NetworkTrafficRedirect] = []
    var taskInterval: DateInterval?
    var transactions: [NetworkTrafficTransaction] = []
    var receivedMetrics = false
  }

  private let policy: NetworkTrafficCapturePolicy
  package let forwardingDelegate: (any URLSessionTaskDelegate)?
  private let lock = NSLock()
  private var state = State()

  package init(
    policy: NetworkTrafficCapturePolicy,
    forwardingTo originalTaskDelegate: (any URLSessionTaskDelegate)? = nil
  ) {
    self.policy = policy
    self.forwardingDelegate = originalTaskDelegate
  }

  package func recordRedirect(response: HTTPURLResponse, request: URLRequest) {
    let redirect = NetworkTrafficSnapshot.redirect(
      response: response,
      request: request,
      policy: policy
    )
    lock.lock()
    state.redirects.append(redirect)
    lock.unlock()
  }

  package func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didFinishCollecting metrics: URLSessionTaskMetrics
  ) {
    let transactions = metrics.transactionMetrics.map {
      NetworkTrafficSnapshot.transaction(from: $0, policy: policy)
    }
    lock.lock()
    state.taskInterval = metrics.taskInterval
    state.transactions = transactions
    state.receivedMetrics = true
    lock.unlock()
    forwardingDelegate?.urlSession?(session, task: task, didFinishCollecting: metrics)
  }

  package func snapshot(
    waitingUpTo timeout: Swift.Duration = Swift.Duration.milliseconds(50)
  ) async -> NetworkTrafficDelegateSnapshot {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)

    while true {
      let snapshot = currentSnapshot()
      if snapshot.receivedMetrics || clock.now >= deadline || Task.isCancelled {
        return snapshot
      }
      do {
        try await Task.sleep(for: Swift.Duration.milliseconds(1))
      } catch {
        return currentSnapshot()
      }
    }
  }

  private func currentSnapshot() -> NetworkTrafficDelegateSnapshot {
    lock.lock()
    let snapshot = NetworkTrafficDelegateSnapshot(
      redirects: state.redirects,
      taskInterval: state.taskInterval,
      transactions: state.transactions,
      receivedMetrics: state.receivedMetrics
    )
    lock.unlock()
    return snapshot
  }
}
