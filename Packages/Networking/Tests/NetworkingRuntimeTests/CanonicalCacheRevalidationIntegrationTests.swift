import Foundation
@testable import NetworkingRuntime
import NetworkingDSL
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
    let request = try HTTPRequest { GET(url.absoluteString) }

    let initialResponse = try await client.execute(request)
    #expect(initialResponse.body == cachedBody)

    let revalidatedResponse = try await client.execute(request)
    #expect(revalidatedResponse.status == HTTPStatus.ok)
    #expect(revalidatedResponse.body == cachedBody)

    let refreshedEntry = try #require(await middleware.getCachedEntry(for: request))
    #expect(refreshedEntry.expiresAt > Date())
  }

  @Test(
    "DSL persistent storage revalidates across clients",
    arguments: PersistentCacheKind.allCases
  )
  func dslPersistentStorageRevalidatesAcrossClients(kind: PersistentCacheKind) async throws {
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
    let storagePath = CacheStoragePath(rawValue: cacheDirectory.path)
    let request = try HTTPRequest { GET(url.absoluteString) }

    try await assertPersistentRevalidations(
      request: request,
      body: cachedBody,
      session: session,
      storage: kind.storage(path: storagePath)
    )
  }

  private func assertPersistentRevalidations(
    request: HTTPRequest,
    body: HTTPBody,
    session: URLSession,
    storage: CacheStorage
  ) async throws {
    let firstClient = try makeDSLClient(
      session: session,
      storage: storage
    )
    let initialResponse = try await firstClient.execute(request)
    #expect(initialResponse.body == body)

    let secondClient = try makeDSLClient(
      session: session,
      storage: storage
    )
    let firstRevalidation = try await secondClient.execute(request)
    #expect(firstRevalidation.status == HTTPStatus.ok)
    #expect(firstRevalidation.body == body)

    let thirdClient = try makeDSLClient(
      session: session,
      storage: storage
    )
    let secondRevalidation = try await thirdClient.execute(request)
    #expect(secondRevalidation.status == HTTPStatus.ok)
    #expect(secondRevalidation.body == body)
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

  private func makeDSLClient(session: URLSession, storage: CacheStorage) throws -> NetworkClient {
    try NetworkClient {
      CustomSession(session)
      Caching {
        Policy.standard()
        Storage(storage)
        Duration.ttl(0)
      }
    }
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

enum PersistentCacheKind: CaseIterable, Sendable {
  case disk
  case hybrid

  func storage(path: CacheStoragePath) -> CacheStorage {
    switch self {
    case .disk:
      return .disk(size: .MB(1), path: path)
    case .hybrid:
      return .hybrid(memorySize: .MB(1), diskSize: .MB(1), path: path)
    }
  }
}
