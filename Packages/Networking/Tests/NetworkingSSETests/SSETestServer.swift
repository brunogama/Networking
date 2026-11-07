import Foundation
import Network

final class SSETestServer: Sendable {
  private let listener: NWListener
  private let queue = DispatchQueue(label: "NetworkingSSETests.SSETestServer")
  private let state: SSETestServerState
  private let connections: AsyncStream<NWConnection>.Continuation
  private let serving: Task<Void, Never>

  init(scripts: [SSETestResponseScript]) throws {
    let listener = try NWListener(using: .tcp, on: .any)
    let state = SSETestServerState(scripts: scripts)
    let accepted = AsyncStream<NWConnection>.makeStream()
    self.listener = listener
    self.state = state
    connections = accepted.continuation
    let queue = self.queue
    listener.newConnectionHandler = { connection in
      accepted.continuation.yield(connection)
    }
    serving = Task {
      await withTaskGroup(of: Void.self) { group in
        for await connection in accepted.stream {
          connection.start(queue: queue)
          group.addTask { await Self.serve(connection, state: state) }
        }
        group.cancelAll()
      }
    }
  }

  deinit { stop() }

  func start() async throws {
    let ready = readiness()
    listener.start(queue: queue)
    try await withTaskCancellationHandler {
      for try await _ in ready { break }
      try Task.checkCancellation()
    } onCancel: {
      self.stop()
    }
  }

  private func readiness() -> AsyncThrowingStream<Void, any Error> {
    AsyncThrowingStream { continuation in
      listener.stateUpdateHandler = { state in
        switch state {
        case .ready:
          continuation.yield(())
          continuation.finish()
        case .failed(let error): continuation.finish(throwing: error)
        case .cancelled: continuation.finish(throwing: CancellationError())
        default: break
        }
      }
    }
  }

  func stop() {
    listener.cancel()
    connections.finish()
    serving.cancel()
  }

  func waitUntilStopped() async { await serving.value }

  func makeURL(path: String) throws -> URL {
    guard let port = listener.port?.rawValue,
      let baseURL = URL(string: "http://127.0.0.1:\(port)")
    else { throw SSETestServerError.invalidBaseURL }
    let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
    guard let url = URL(string: normalizedPath, relativeTo: baseURL)?.absoluteURL else {
      throw SSETestServerError.invalidBaseURL
    }

    return url
  }

  func capturedRequests() async -> [SSECapturedRequest] {
    await state.requests()
  }

}
