import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

final class CacheHTTPFixture: Sendable {
  let context = MockContextIdentifier()
  let url: HTTPRequestURL
  let session: URLSession
  let cache: CachingMiddleware
  let client: NetworkClient

  init() throws {
    url = HTTPRequestURL(try #require(URL(string: "https://cache.example/profile")))
    session = URLSession(configuration: MockURLProtocol.createMockConfiguration(contextID: context))
    cache = CachingMiddleware(
      configuration: .init(),
      storage: MemoryCacheStorage(),
      client: NetworkClient(session: session)
    )
    client = NetworkClient(
      session: session,
      middleware: HTTPMiddleware(request: [cache], response: [cache])
    )
  }

  deinit {
    session.invalidateAndCancel()
    MockURLProtocol.clearAll(contextID: context)
  }

  func request(cookie: String) -> HTTPRequest {
    HTTPRequest(method: .get, url: url, headers: HTTPHeaders(rawValue: ["Cookie": cookie]))
  }
}
