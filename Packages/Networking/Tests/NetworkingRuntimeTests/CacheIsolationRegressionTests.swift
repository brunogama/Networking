import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

@Suite("Cache isolation and task lifetime")
struct CacheIsolationRegressionTests {
  @Test("Trace propagation permits cache hits unless the response varies on trace headers")
  func tracingDoesNotChangeRepresentation() async throws {
    var first = try cacheRequest()
    first.addHeader(name: "traceparent", value: "first-span")
    var second = first
    second.addHeader(name: "traceparent", value: "second-span")
    let cache = CachingMiddleware(
      configuration: .init(),
      storage: MemoryCacheStorage(),
      client: NetworkClient()
    )
    _ = try await cache.processResponse(HTTPResponse(request: first, status: .ok), for: first)
    #expect(await cache.cachedResponse(for: second) != nil)
    await cache.clearCache()
    _ = try await cache.processResponse(
      HTTPResponse(request: first, status: .ok, headers: ["Vary": "traceparent"]),
      for: first
    )
    #expect(await cache.cachedResponse(for: second) == nil)
  }

  @Test("Cookie accounts do not share cached responses and cache hits keep the current request ID")
  func accountIsolationAndIdentity() async throws {
    let fixture = try CacheHTTPFixture()
    MockURLProtocol.stubSequential(
      url: fixture.url,
      responses: [
        .success(statusCode: 200, data: HTTPBody(Data("alice".utf8)), headers: ["Vary": "Cookie"]),
        .success(statusCode: 200, data: HTTPBody(Data("bob".utf8)), headers: ["Vary": "Cookie"]),
      ],
      contextID: fixture.context
    )
    _ = try await fixture.client.execute(fixture.request(cookie: "alice"))
    let repeated = fixture.request(cookie: "alice")
    let cached = try await fixture.client.execute(repeated)
    let other = try await fixture.client.execute(fixture.request(cookie: "bob"))
    #expect(cached.request.id == repeated.id)
    #expect(cached.body == HTTPBody(Data("alice".utf8)))
    #expect(other.body == HTTPBody(Data("bob".utf8)))
    #expect(
      await MockURLProtocol.getRequestCount(for: fixture.url, contextID: fixture.context) == 2
    )
  }

  @Test("Invalidation while prefetch is suspended prevents old work from repopulating storage")
  func invalidationDuringPrefetch() async throws {
    let pause = CachePause()
    let storage = MemoryCacheStorage()
    let cache = CachingMiddleware(
      configuration: .init(),
      storage: storage,
      client: PausedCacheClient(pause: pause)
    )
    let request = try cacheRequest()
    let operation = Task { await cache.prefetchSingle(request: request) }
    var arrivals = pause.arrivals.stream.makeAsyncIterator()
    _ = await arrivals.next()
    await cache.clearCache()
    await pause.release()
    let result = await operation.value
    #expect(!result.isSuccess.rawValue)
    #expect(await storage.keys().isEmpty)
  }

  @Test("Cancellation reaches caller-owned prefetch and leaves no cached entry")
  func cancellationDoesNotPublish() async throws {
    let client = CancellationCacheClient()
    let storage = MemoryCacheStorage()
    let cache = CachingMiddleware(configuration: .init(), storage: storage, client: client)
    let request = try cacheRequest()
    let operation = Task { await cache.prefetchSingle(request: request) }
    var started = client.started.stream.makeAsyncIterator()
    _ = await started.next()
    operation.cancel()
    let result = await operation.value
    #expect(!result.isSuccess.rawValue)
    #expect(await storage.keys().isEmpty)
  }

  @Test("Concurrent prefetch of one URL keeps credential partitions independent")
  func concurrentAccountIsolation() async throws {
    let pause = CachePause()
    let cache = CachingMiddleware(
      configuration: .init(),
      storage: MemoryCacheStorage(),
      client: PausedCacheClient(pause: pause)
    )
    let alice = try cacheRequest(cookie: "alice")
    let bob = try cacheRequest(cookie: "bob")
    async let first = cache.prefetchSingle(request: alice)
    async let second = cache.prefetchSingle(request: bob)
    var arrivals = pause.arrivals.stream.makeAsyncIterator()
    _ = await arrivals.next()
    _ = await arrivals.next()
    await pause.release()
    let results = await [first, second]
    #expect(results.allSatisfy { $0.isSuccess.rawValue })
    #expect(await cache.cachedResponse(for: alice)?.body == HTTPBody(Data("alice".utf8)))
    #expect(await cache.cachedResponse(for: bob)?.body == HTTPBody(Data("bob".utf8)))
  }

  @Test("Vary wildcard responses are not reused even under a custom eligibility predicate")
  func varyWildcardIsNeverCached() async throws {
    let request = try cacheRequest()
    let cache = CachingMiddleware(
      configuration: .init(shouldCache: { _, _ in true }),
      storage: MemoryCacheStorage(),
      client: NetworkClient()
    )
    _ = try await cache.processResponse(
      HTTPResponse(request: request, status: .ok, headers: ["Vary": "*"]),
      for: request
    )
    #expect(await cache.cachedResponse(for: request) == nil)
  }
}
