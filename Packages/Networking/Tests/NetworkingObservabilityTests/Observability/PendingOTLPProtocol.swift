import Foundation
import NetworkingCore
import NetworkingObservability
import NetworkingObservabilityOTLP
import os
import Testing

// URLProtocol adds no instance state; its shared continuation registry is synchronized.
final class PendingOTLPProtocol: URLProtocol, @unchecked Sendable {
  private static let signals = OSAllocatedUnfairLock(
    initialState: [String: AsyncStream<Event>.Continuation]()
  )

  static func register(_ endpoint: URL) -> AsyncStream<Event> {
    let pair = AsyncStream<Event>.makeStream()
    signals.withLock { $0[endpoint.host ?? ""] = pair.continuation }
    return pair.stream
  }

  static func remove(_ endpoint: URL) {
    signals.withLock { $0.removeValue(forKey: endpoint.host ?? "") }?.finish()
  }

  override static func canInit(with request: URLRequest) -> Bool { true }
  override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.signals.withLock { $0[request.url?.host ?? ""] }?.yield(.started)
  }

  override func stopLoading() {
    Self.signals.withLock { $0[request.url?.host ?? ""] }?.yield(.stopped)
  }
}
