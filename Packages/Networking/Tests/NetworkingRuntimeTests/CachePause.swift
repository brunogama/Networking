import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

actor CachePause {
  let arrivals = AsyncStream<Void>.makeStream()
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func suspend() async {
    await withCheckedContinuation { continuation in
      waiters.append(continuation)
      arrivals.continuation.yield(())
    }
  }

  func release() {
    let current = waiters
    waiters.removeAll()
    for continuation in current { continuation.resume() }
  }
}
