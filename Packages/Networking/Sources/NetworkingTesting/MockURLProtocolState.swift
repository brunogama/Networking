import Foundation
import NetworkingCore
import os

final class MockURLProtocolState: Sendable {
  private let storage = OSAllocatedUnfairLock(initialState: Storage())

  func addStub(_ stub: MockURLRequestStub) {
    storage.withLock { $0.entries.append(Entry(stub: stub)) }
  }

  func capture(_ request: URLRequest) {
    storage.withLock { $0.requests.append(request) }
  }

  func consume(for request: URLRequest) -> MockURLRequestStub? {
    while true {
      let candidates = storage.withLock { $0.entries }
      guard let candidate = candidates.first(where: { $0.stub.matches(request) }) else {
        return nil
      }
      if let consumed = storage.withLock({ $0.consume(candidate.id) }) { return consumed }
    }
  }

  func getCapturedRequests(contextID: MockContextIdentifier?) -> [URLRequest] {
    let requests = storage.withLock { $0.requests }
    return requests.filter { matches($0, contextID: contextID) }.map { request in
      var sanitized = request
      sanitized.setValue(nil, forHTTPHeaderField: MockURLProtocol.contextHeader)
      return sanitized
    }
  }

  func getRequestCount(
    for url: HTTPRequestURL,
    contextID: MockContextIdentifier?
  ) -> MockVerificationCount {
    MockVerificationCount(
      getCapturedRequests(contextID: contextID).filter { $0.url == url.rawValue }.count
    )
  }

  func getStubCount() -> MockVerificationCount {
    storage.withLock { MockVerificationCount($0.entries.count) }
  }

  func clearAll(contextID: MockContextIdentifier?) {
    storage.withLock { state in
      guard let contextID else {
        state.entries.removeAll()
        state.requests.removeAll()
        return
      }
      state.entries.removeAll { $0.stub.contextID == contextID }
      state.requests.removeAll { matches($0, contextID: contextID) }
    }
  }

  private func matches(_ request: URLRequest, contextID: MockContextIdentifier?) -> Bool {
    guard let contextID else { return true }
    return request.value(forHTTPHeaderField: MockURLProtocol.contextHeader)
      == contextID.rawValue.uuidString
  }
}
