import Foundation
import NetworkingCore
import NetworkingRuntime
import Testing

actor SuspendedTokenExchange {
  private var started = false
  private var startWaiter: CheckedContinuation<Void, Never>?
  private var completion: CheckedContinuation<BearerTokenValue, Never>?

  func refresh() async -> BearerTokenValue {
    await withCheckedContinuation { continuation in
      completion = continuation
      started = true
      startWaiter?.resume()
      startWaiter = nil
    }
  }

  func waitUntilStarted() async {
    guard !started else { return }
    await withCheckedContinuation { startWaiter = $0 }
  }

  func finish() {
    completion?.resume(returning: "refreshed")
    completion = nil
  }

  func finishAfterMutation(_ mutation: @Sendable () async throws -> Void) async rethrows {
    defer { finish() }
    try await mutation()
  }
}
