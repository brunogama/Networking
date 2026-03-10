import Foundation
import Network

struct SSETestChunk: Sendable {
  let data: Data
  let delay: TimeInterval

  init(_ string: String, delay: TimeInterval = 0) {
    data = Data(string.utf8)
    self.delay = delay
  }
}

struct SSETestResponseScript: Sendable {
  let statusCode: Int
  let headers: [String: String]
  let chunks: [SSETestChunk]

  init(
    statusCode: Int = 200,
    headers: [String: String] = ["Content-Type": "text/event-stream"],
    chunks: [SSETestChunk]
  ) {
    self.statusCode = statusCode
    self.headers = headers
    self.chunks = chunks
  }
}

struct SSECapturedRequest: Sendable {
  let method: String
  let path: String
  let headers: [String: String]
}

actor SSETestServerState {
  private var scripts: [SSETestResponseScript]
  private var capturedRequests: [SSECapturedRequest] = []

  init(scripts: [SSETestResponseScript]) {
    self.scripts = scripts
  }

  func nextScript() -> SSETestResponseScript? {
    guard !scripts.isEmpty else {
      return nil
    }

    return scripts.removeFirst()
  }

  func record(_ request: SSECapturedRequest) {
    capturedRequests.append(request)
  }

  func requests() -> [SSECapturedRequest] {
    capturedRequests
  }
}

enum SSETestServerError: Error {
  case invalidBaseURL
  case invalidRequest
  case connectionClosed
}

final class SSETestServerStartCoordinator: @unchecked Sendable {
  private var continuation: CheckedContinuation<Void, Error>?

  init(continuation: CheckedContinuation<Void, Error>) {
    self.continuation = continuation
  }

  func resume() {
    continuation?.resume()
    continuation = nil
  }

  func resume(throwing error: Error) {
    continuation?.resume(throwing: error)
    continuation = nil
  }
}

final class SSETestServer: @unchecked Sendable {
  let listener: NWListener
  let queue = DispatchQueue(label: "NetworkingSSETests.SSETestServer")
  let state: SSETestServerState
  var baseURL: URL?

  init(scripts: [SSETestResponseScript]) throws {
    listener = try NWListener(using: .tcp, on: .any)
    state = SSETestServerState(scripts: scripts)
  }

  func start() async throws {
    try await withCheckedThrowingContinuation { continuation in
      let coordinator = SSETestServerStartCoordinator(continuation: continuation)

      listener.stateUpdateHandler = { [weak self] state in
        self?.handleListenerState(state, coordinator: coordinator)
      }

      listener.newConnectionHandler = { [weak self] connection in
        self?.start(connection)
      }

      listener.start(queue: queue)
    }
  }

  func stop() {
    listener.cancel()
  }

  deinit {
    listener.cancel()
  }

  func makeURL(path: String) throws -> URL {
    guard let baseURL else {
      throw SSETestServerError.invalidBaseURL
    }

    let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
    guard let url = URL(string: normalizedPath, relativeTo: baseURL)?.absoluteURL else {
      throw SSETestServerError.invalidBaseURL
    }

    return url
  }

  func capturedRequests() async -> [SSECapturedRequest] {
    await state.requests()
  }

  private func start(_ connection: NWConnection) {
    connection.start(queue: queue)

    Task { @Sendable [weak self] in
      await self?.serve(connection)
    }
  }

  private func handleListenerState(
    _ state: NWListener.State,
    coordinator: SSETestServerStartCoordinator
  ) {
    switch state {
    case .ready:
      guard
        let port = listener.port?.rawValue,
        let url = URL(string: "http://127.0.0.1:\(port)")
      else {
        coordinator.resume(throwing: SSETestServerError.invalidBaseURL)
        return
      }

      baseURL = url
      coordinator.resume()

    case .failed(let error):
      coordinator.resume(throwing: error)

    default:
      break
    }
  }
}
