import Foundation
import Testing

@testable import NetworkingTesting
@testable import NetworkingRuntime
import NetworkingObservability
@Suite("Mock Infrastructure Tests")
struct MockInfrastructureTests {
  // MARK: - MockCacheStorage Tests

  @Test("MockCacheStorage returns stubbed entry when key exists")
  func cacheStorage_returnsStubbed_whenKeyExists() async throws {
    let mock = MockCacheStorage()
    let entry = CachingMiddleware.CacheEntry(
      response: HTTPResponse(
        request: HTTPRequest(method: .get, url: URL(string: "https://example.com")!),
        status: .ok,
        body: nil as HTTPBody?
      ),
      ttl: 300
    )

    await mock.stub(key: "test-key", entry: entry)

    let retrieved = await mock.get("test-key")
    #expect(retrieved != nil)
    #expect(retrieved?.response.status == .ok)
  }

  @Test("MockCacheStorage returns nil when key missing")
  func cacheStorage_returnsNil_whenKeyMissing() async {
    let mock = MockCacheStorage()

    let retrieved = await mock.get("nonexistent-key")

    #expect(retrieved == nil)
  }

  @Test("MockCacheStorage stores entry via set")
  func cacheStorage_storesEntry_viaSet() async throws {
    let mock = MockCacheStorage()
    let entry = CachingMiddleware.CacheEntry(
      response: HTTPResponse(
        request: HTTPRequest(method: .get, url: URL(string: "https://example.com")!),
        status: .ok,
        body: nil as HTTPBody?
      ),
      ttl: 300
    )

    await mock.set("key1", entry: entry)

    let retrieved = await mock.get("key1")
    #expect(retrieved != nil)
  }

  @Test("MockCacheStorage deletes entry via remove")
  func cacheStorage_deletesEntry_viaRemove() async throws {
    let mock = MockCacheStorage()
    let entry = CachingMiddleware.CacheEntry(
      response: HTTPResponse(
        request: HTTPRequest(method: .get, url: URL(string: "https://example.com")!),
        status: .ok,
        body: nil as HTTPBody?
      ),
      ttl: 300
    )

    await mock.set("key1", entry: entry)
    await mock.remove("key1")

    let retrieved = await mock.get("key1")
    #expect(retrieved == nil)
  }

  @Test("MockCacheStorage verifyGet succeeds after get")
  func cacheStorage_verifyGet_succeedsAfterGet() async throws {
    let mock = MockCacheStorage()

    _ = await mock.get("test-key")

    try await mock.verifyGet("test-key", times: 1)
  }

  @Test("MockCacheStorage verifySet succeeds after set")
  func cacheStorage_verifySet_succeedsAfterSet() async throws {
    let mock = MockCacheStorage()
    let entry = CachingMiddleware.CacheEntry(
      response: HTTPResponse(
        request: HTTPRequest(method: .get, url: URL(string: "https://example.com")!),
        status: .ok,
        body: nil as HTTPBody?
      ),
      ttl: 300
    )

    await mock.set("test-key", entry: entry)

    try await mock.verifySet("test-key", times: 1)
  }

  // MARK: - MockTraceExporter Tests

  @Test("MockTraceExporter captures spans")
  func traceExporter_capturesSpans() async throws {
    let mock = MockTraceExporter()
    let context = TraceContext()
    let span = TraceSpan(
      name: "test-operation",
      context: context,
      startTime: Date()
    )

    try await mock.export(span)

    let exported = await mock.getExportedSpans()
    #expect(exported.count == 1)
    #expect(exported[0].name == "test-operation")
  }

  @Test("MockTraceExporter verifies span exported")
  func traceExporter_verifySpanExported() async throws {
    let mock = MockTraceExporter()
    let context = TraceContext()
    let span = TraceSpan(
      name: "test-operation",
      context: context,
      startTime: Date()
    )

    try await mock.export(span)

    try await mock.verifySpanExported(withName: "test-operation")
  }
}
