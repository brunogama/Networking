import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Records an ordered, bounded history of physical requests made by `NetworkClient`.
///
/// Recording is opt in. The default policy keeps request shape and timing metadata while
/// omitting query values, header values, and bodies.
/// It covers `NetworkClient` data requests. Native file transfers, background transfers, and
/// server-sent events use separate paths and are not recorded.
///
/// ```swift
/// let recorder = NetworkTrafficRecorder()
/// let client = NetworkClient(trafficRecorder: recorder)
/// _ = try await client.execute(request)
/// let attempts = await recorder.records()
/// ```
public actor NetworkTrafficRecorder {
  nonisolated public let capturePolicy: NetworkTrafficCapturePolicy

  private let capacity: Int
  private var nextSequence: UInt64 = 0
  private var pending: [UUID: PendingAttempt] = [:]
  private var completed: [NetworkTrafficRecord] = []

  public init(
    capacity: Int = 100,
    capturePolicy: NetworkTrafficCapturePolicy = .metadataOnly
  ) {
    self.capacity = max(capacity, 1)
    self.capturePolicy = capturePolicy
  }

  /// Returns completed attempts in the order their physical requests started.
  public func records() -> [NetworkTrafficRecord] {
    completed
  }

  /// Removes completed records and in-flight attempts that began before this call.
  public func clear() {
    pending.removeAll(keepingCapacity: true)
    completed.removeAll(keepingCapacity: true)
  }

  package func begin(
    requestID: HTTPRequestID,
    request: URLRequest,
    startedAt: Date
  ) -> NetworkTrafficAttemptToken {
    let token = NetworkTrafficAttemptToken(id: UUID())
    pending[token.id] = PendingAttempt(
      sequence: nextSequence,
      requestID: requestID,
      startedAt: startedAt,
      request: NetworkTrafficSnapshot.request(from: request, policy: capturePolicy)
    )
    nextSequence &+= 1
    return token
  }

  package func complete(
    _ token: NetworkTrafficAttemptToken,
    with result: NetworkTrafficAttemptResult
  ) {
    guard let attempt = pending.removeValue(forKey: token.id) else {
      return
    }

    completed.append(
      NetworkTrafficRecord(
        id: token.id,
        sequence: attempt.sequence,
        requestID: attempt.requestID,
        startedAt: attempt.startedAt,
        endedAt: result.endedAt,
        request: attempt.request,
        response: result.response,
        failure: result.failure,
        redirects: result.delegateSnapshot.redirects,
        taskInterval: result.delegateSnapshot.taskInterval,
        transactions: result.delegateSnapshot.transactions
      )
    )
    completed.sort { $0.sequence < $1.sequence }
    if completed.count > capacity {
      completed.removeFirst(completed.count - capacity)
    }
  }
}

package struct NetworkTrafficAttemptToken: Sendable {
  package let id: UUID
}

package struct NetworkTrafficAttemptResult: Sendable {
  package let endedAt: Date
  package let response: NetworkTrafficResponse?
  package let failure: NetworkTrafficFailure?
  package let delegateSnapshot: NetworkTrafficDelegateSnapshot
}

private struct PendingAttempt: Sendable {
  let sequence: UInt64
  let requestID: HTTPRequestID
  let startedAt: Date
  let request: NetworkTrafficRequest
}
