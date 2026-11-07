import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import Testing

@Suite("Cache storage persistence and invalidation")
struct CacheStorageRegressionTests {
  @Test("Tag invalidation survives disk restart and preserves unrelated entries")
  func tagsSurviveDiskRestart() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let original = try DiskCacheStorage(cacheDirectory: CacheDirectoryURL(directory))
    var entry = CachingMiddleware.CacheEntry(
      response: HTTPResponse(request: try cacheRequest(), status: .ok),
      ttl: 60
    )
    entry.tags = ["account", "account"]
    await original.set("tagged", entry: entry)
    entry.tags = ["public"]
    await original.set("untagged", entry: entry)
    let reopened = try DiskCacheStorage(
      cacheDirectory: CacheDirectoryURL(directory),
      compressionEnabled: false
    )
    #expect(await reopened.get("tagged")?.tags == ["account"])
    await reopened.removeByTags(["account", "account"])
    let verifier = try DiskCacheStorage(cacheDirectory: CacheDirectoryURL(directory))
    #expect(await verifier.get("tagged") == nil)
    #expect(await verifier.get("untagged") != nil)
  }

  @Test("Clear preserves unrelated files and directories")
  func clearPreservesUnrelatedFiles() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = try DiskCacheStorage(cacheDirectory: CacheDirectoryURL(directory))
    let unrelated = directory.appendingPathComponent("unrelated.cache")
    let nested = directory.appendingPathComponent(String(repeating: "a", count: 64) + ".cache")
    try Data("keep".utf8).write(to: unrelated)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    await cache.set(
      "entry",
      entry: .init(
        response: HTTPResponse(request: try cacheRequest(), status: .ok),
        ttl: 60
      )
    )
    await cache.removeAll()
    #expect(await cache.keys().isEmpty)
    #expect(try Data(contentsOf: unrelated) == Data("keep".utf8))
    #expect(FileManager.default.fileExists(atPath: nested.path))
  }

  @Test("Wildcard invalidation escapes regex characters and matches the complete key")
  func literalPatternAcrossStores() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let stores: [any HTTPResponseCacheStorage] = [
      MemoryCacheStorage(), AdvancedMemoryCacheStorage(),
      try DiskCacheStorage(cacheDirectory: CacheDirectoryURL(directory)),
    ]
    let entry = CachingMiddleware.CacheEntry(
      response: HTTPResponse(request: try cacheRequest(), status: .ok),
      ttl: 60
    )
    for store in stores {
      await store.set("account.[1]", entry: entry)
      await store.set("accountX1", entry: entry)
      await store.set("account.[1]\n", entry: entry)
      await store.set("prefix:account.[1]", entry: entry)
      await store.removeByPattern("account.[1]")
      #expect(await store.get("account.[1]") == nil)
      #expect(await store.get("accountX1") != nil)
      #expect(await store.get("account.[1]\n") != nil)
      #expect(await store.get("prefix:account.[1]") != nil)
      await store.removeByPattern("prefix:account.???")
      #expect(await store.get("prefix:account.[1]") == nil)
    }
  }

  @Test("Basic memory storage honors metadata tags and a zero capacity")
  func memoryTagsAndCapacity() async throws {
    var entry = CachingMiddleware.CacheEntry(
      response: HTTPResponse(request: try cacheRequest(), status: .ok),
      ttl: 60
    )
    entry.tags = ["account"]
    let memory = MemoryCacheStorage()
    await memory.set("entry", entry: entry)
    await memory.removeByTags(["account"])
    #expect(await memory.keys().isEmpty)
    let disabled = MemoryCacheStorage(maxSize: 0)
    await disabled.set("entry", entry: entry)
    #expect(await disabled.keys().isEmpty)
  }
}
