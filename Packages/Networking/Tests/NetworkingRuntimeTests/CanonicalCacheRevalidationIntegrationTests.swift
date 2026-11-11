import Foundation
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

@Suite("Canonical cache revalidation integration")
struct CacheRevalidationIntegrationTests {
  @Test("An expired ETag response is revalidated and its expiry is refreshed")
  func expiredETagResponseIsRevalidatedAndRefreshed() async throws {
    let contextID = MockContextIdentifier()
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }

    let url = HTTPRequestURL(try #require(URL(string: "https://cache.example.com/resource")))
    let cachedBody = HTTPBody(Data("cached response".utf8))
    stubExpiredResponseRevalidation(url: url, body: cachedBody, contextID: contextID)

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }

    let (client, middleware) = makeCanonicalCacheClient(session: session)
    let request = HTTPRequest(method: .get, url: url)

    let initialResponse = try await client.execute(request)
    #expect(initialResponse.body == cachedBody)

    let revalidatedResponse = try await client.execute(request)
    #expect(revalidatedResponse.status == HTTPStatus.ok)
    #expect(revalidatedResponse.body == cachedBody)

    let refreshedEntry = try #require(await middleware.getCachedEntry(for: request))
    #expect(refreshedEntry.expiresAt > Date())
  }

  @Test(
    "Persistent storage revalidates across clients",
    arguments: PersistentCacheKind.allCases
  )
  func persistentStorageRevalidatesAcrossClients(kind: PersistentCacheKind) async throws {
    let contextID = MockContextIdentifier()
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }

    let identifier = UUID().uuidString
    let url = HTTPRequestURL(
      try #require(URL(string: "https://cache.example.com/persistent/\(identifier)"))
    )
    let cacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "networking-cache-revalidation-\(identifier)",
      isDirectory: true
    )
    defer { try? FileManager.default.removeItem(at: cacheDirectory) }

    let cachedBody = HTTPBody(Data("persisted response".utf8))
    stubPersistentRevalidations(url: url, body: cachedBody, contextID: contextID)

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }
    let request = HTTPRequest(method: .get, url: url)

    for _ in 0..<3 {
      let storage = try kind.storage(directory: cacheDirectory)
      let cache = CachingMiddleware(
        configuration: .init(defaultTTL: 0),
        storage: storage,
        client: NetworkClient(session: session)
      )
      let client = NetworkClient(
        session: session,
        middleware: HTTPMiddleware(request: [cache], response: [cache])
      )
      let response = try await client.execute(request)
      #expect(response.status == .ok)
      #expect(response.body == cachedBody)
    }
  }

  private func makeCanonicalCacheClient(
    session: URLSession
  ) -> (client: NetworkClient, middleware: CachingMiddleware) {
    let middleware = CachingMiddleware(
      configuration: CachingMiddleware.Configuration(),
      storage: MemoryCacheStorage(),
      client: NetworkClient(session: session)
    )
    let client = NetworkClient(
      session: session,
      requestMiddlewares: [middleware],
      responseMiddlewares: [middleware]
    )
    return (client, middleware)
  }

  private func stubExpiredResponseRevalidation(
    url: HTTPRequestURL,
    body: HTTPBody,
    contextID: MockContextIdentifier
  ) {
    MockURLProtocol.stub(
      matching: .url(url),
      response: .success(
        statusCode: 200,
        data: body,
        headers: ["Cache-Control": "max-age=0", "ETag": "\"v1\""]
      ),
      maxUsageCount: 1,
      contextID: contextID
    )
    MockURLProtocol.stub(
      matching: .url(url),
      .header(name: "If-None-Match", value: "\"v1\""),
      response: .success(
        statusCode: 304,
        data: HTTPBody(Data()),
        headers: ["Cache-Control": "max-age=60"]
      ),
      maxUsageCount: 1,
      contextID: contextID
    )
  }

  private func stubPersistentRevalidations(
    url: HTTPRequestURL,
    body: HTTPBody,
    contextID: MockContextIdentifier
  ) {
    MockURLProtocol.stub(
      matching: .url(url),
      response: .success(
        statusCode: 200,
        data: body,
        headers: ["Cache-Control": "max-age=0", "ETag": "\"v1\""]
      ),
      maxUsageCount: 1,
      contextID: contextID
    )
    MockURLProtocol.stub(
      matching: .url(url),
      .header(name: "If-None-Match", value: "\"v1\""),
      response: .success(
        statusCode: 304,
        data: HTTPBody(Data()),
        headers: ["ETag": "\"v2\""]
      ),
      maxUsageCount: 1,
      contextID: contextID
    )
    MockURLProtocol.stub(
      matching: .url(url),
      .header(name: "If-None-Match", value: "\"v2\""),
      response: .success(statusCode: 304, data: HTTPBody(Data())),
      maxUsageCount: 1,
      contextID: contextID
    )
  }
}
