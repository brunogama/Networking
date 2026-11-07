import Foundation
import os

final class StoppingProtocolClient: NSObject, URLProtocolClient, Sendable {
  private let storage = OSAllocatedUnfairLock(initialState: [String]())
  var events: [String] { storage.withLock { $0 } }

  func urlProtocol(
    _ loader: URLProtocol,
    didReceive response: URLResponse,
    cacheStoragePolicy policy: URLCache.StoragePolicy
  ) {
    storage.withLock { $0.append("response") }
    loader.stopLoading()
  }

  func urlProtocol(_ loader: URLProtocol, didLoad data: Data) {
    storage.withLock { $0.append("data") }
  }

  func urlProtocolDidFinishLoading(_ loader: URLProtocol) {
    storage.withLock { $0.append("finished") }
  }

  func urlProtocol(_ loader: URLProtocol, didFailWithError error: any Error) {
    storage.withLock { $0.append("failed") }
  }

  func urlProtocol(
    _ loader: URLProtocol,
    wasRedirectedTo request: URLRequest,
    redirectResponse: URLResponse
  ) {}

  func urlProtocol(_ loader: URLProtocol, cachedResponseIsValid response: CachedURLResponse) {}
  func urlProtocol(_ loader: URLProtocol, didReceive challenge: URLAuthenticationChallenge) {}
  func urlProtocol(_ loader: URLProtocol, didCancel challenge: URLAuthenticationChallenge) {}
}
