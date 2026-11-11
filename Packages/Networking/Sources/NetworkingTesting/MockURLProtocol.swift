import Foundation
import NetworkingCore

/// Intercepts URLSession requests using context-scoped response stubs.
///
/// Immediate responses are delivered synchronously. Delayed responses use one owned task that
/// cancellation and deinitialization stop. The inherited Foundation boundary requires unchecked
/// Sendable conformance: a recursive lock serializes every mutable field and client callback,
/// including reentrant stopLoading calls. No lock spans an await.
public final class MockURLProtocol: URLProtocol, @unchecked Sendable {
  static let contextHeader = "X-Networking-Mock-Context"
  static let mockState = MockURLProtocolState()
  static let codec = JSONCodec()

  private let lifecycle = NSRecursiveLock()
  private var operation: Task<Void, Never>?
  private var started = false
  private var active = false

  override public static func canInit(with request: URLRequest) -> Bool { true }

  override public static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override public func startLoading() {
    lifecycle.withLock {
      guard !started else { return }
      started = true
      active = true
      Self.mockState.capture(request)
      guard let stub = Self.mockState.consume(for: request) else {
        fail(URLError(.fileDoesNotExist))
        return
      }
      stub.requestCapture?(request)
      guard active else { return }
      schedule(stub.response)
    }
  }

  override public func stopLoading() {
    let pending = lifecycle.withLock {
      started = true
      active = false
      let pending = operation
      operation = nil
      return pending
    }
    pending?.cancel()
  }

  private func schedule(_ response: MockResponse) {
    let delay = response.delay.rawValue
    guard delay.isFinite else {
      fail(URLError(.badServerResponse))
      return
    }
    guard delay > 0 else {
      deliver(response)
      return
    }
    operation = Task { @Sendable [weak self] in
      do {
        try await Task.sleep(for: .seconds(delay))
        self?.deliver(response)
      } catch {}
      self?.finishOperation()
    }
  }

  private func finishOperation() {
    lifecycle.withLock { operation = nil }
  }

  private func deliver(_ response: MockResponse) {
    lifecycle.withLock {
      guard active else { return }
      if let error = response.error {
        fail(error)
        return
      }
      deliverSuccess(response)
    }
  }

  private func deliverSuccess(_ response: MockResponse) {
    guard let url = request.url,
      let result = HTTPURLResponse(
        url: url,
        statusCode: response.statusCode.rawValue,
        httpVersion: "HTTP/1.1",
        headerFields: response.headers.rawValue
      )
    else {
      fail(URLError(.badServerResponse))
      return
    }
    client?.urlProtocol(self, didReceive: result, cacheStoragePolicy: .notAllowed)
    guard active else { return }
    client?.urlProtocol(self, didLoad: response.data.rawValue)
    guard active else { return }
    active = false
    client?.urlProtocolDidFinishLoading(self)
  }

  private func fail(_ error: any Error) {
    guard active else { return }
    active = false
    client?.urlProtocol(self, didFailWithError: error)
  }

  deinit {
    operation?.cancel()
  }
}
