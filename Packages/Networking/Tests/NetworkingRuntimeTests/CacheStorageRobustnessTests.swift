import Foundation
@testable import NetworkingRuntime
import NetworkingCore
import Testing

@Suite("Cache storage robustness")
struct CacheStorageRobustnessTests {
  @Test("Cache storage uses real SHA-256 and reversible compression")
  func cacheStorageIntegrityPrimitives() throws {
    let knownInput = Data("abc".utf8)
    #expect(
      knownInput.sha256 == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    )

    let compressibleInput = Data(repeating: 0x41, count: 1_024)
    let compressed = try #require(compressibleInput.compressedForCache())
    #expect(compressed.count < compressibleInput.count)
    #expect(compressed.decompressedForCache() == compressibleInput)
  }

  @Test("Cancelling one semaphore waiter does not resume another")
  func semaphoreCancellationTargetsItsWaiter() async throws {
    let semaphore = AsyncSemaphore(value: 1)
    let state = SemaphoreCompletionState()
    #expect(await semaphore.wait())

    let firstWaiter = Task {
      let acquired = await semaphore.wait()
      if acquired {
        await state.firstEntered()
      }
    }
    try await Task.sleep(for: .milliseconds(20))

    let cancelledWaiter = Task {
      let acquired = await semaphore.wait()
      await state.cancelledFinished(acquired: acquired)
    }
    try await Task.sleep(for: .milliseconds(20))
    cancelledWaiter.cancel()
    try await Task.sleep(for: .milliseconds(20))

    #expect(await state.didCancelFinish)
    #expect(!(await state.didCancelledWaiterAcquire))
    #expect(!(await state.didFirstEnter))

    await semaphore.signal()
    await firstWaiter.value
    await cancelledWaiter.value
    #expect(await state.didFirstEnter)
  }

  @Test("Memory usage counts response bytes")
  func memoryUsageCountsResponseBytes() async throws {
    let cache = AdvancedMemoryCacheStorage(sizePolicy: .maxMemory(1_000))
    let response = try makeResponse(bodyByteCount: 10, headers: ["X": "123"])

    await cache.set("entry", entry: CachingMiddleware.CacheEntry(response: response, ttl: 60))

    #expect(await cache.estimatedMemoryUsage == 14)
  }

  @Test("An entry larger than the memory limit is not retained")
  func oversizedMemoryEntryIsNotRetained() async throws {
    let cache = AdvancedMemoryCacheStorage(sizePolicy: .maxMemory(10))
    let response = try makeResponse(bodyByteCount: 11)

    await cache.set("oversized", entry: CachingMiddleware.CacheEntry(response: response, ttl: 60))

    #expect(await cache.get("oversized") == nil)
    #expect(await cache.estimatedMemoryUsage == 0)
  }

  @Test("Disk cache removes unindexed data files after restart")
  func diskCacheRemovesUnindexedDataFilesAfterRestart() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "networking-disk-cache-\(UUID().uuidString)",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }

    let orphan = directory.appendingPathComponent("orphan.cache")
    try Data("orphan".utf8).write(to: orphan)
    let cache = try DiskCacheStorage(cacheDirectory: CacheDirectoryURL(directory))

    _ = await cache.get("missing")

    #expect(!FileManager.default.fileExists(atPath: orphan.path))
  }

  @Test("Disk cache loads its index before the first mutation after restart")
  func diskCacheLoadsIndexBeforeMutation() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "networking-disk-cache-\(UUID().uuidString)",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }

    let cacheDirectory = CacheDirectoryURL(directory)
    let firstCache = try DiskCacheStorage(cacheDirectory: cacheDirectory)
    let response = try makeResponse(bodyByteCount: 10)
    await firstCache.set(
      "first",
      entry: CachingMiddleware.CacheEntry(response: response, ttl: 60)
    )

    let restartedCache = try DiskCacheStorage(cacheDirectory: cacheDirectory)
    await restartedCache.set(
      "second",
      entry: CachingMiddleware.CacheEntry(response: response, ttl: 60)
    )

    let verifier = try DiskCacheStorage(cacheDirectory: cacheDirectory)
    #expect(await verifier.get("first") != nil)
    #expect(await verifier.get("second") != nil)
  }

  @Test("Disk cache rejects data modified after it was stored")
  func diskCacheRejectsModifiedData() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "networking-disk-cache-\(UUID().uuidString)",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }

    let cache = try DiskCacheStorage(
      cacheDirectory: CacheDirectoryURL(directory),
      compressionEnabled: false
    )
    let response = try makeResponse(bodyByteCount: 10)
    await cache.set(
      "integrity",
      entry: CachingMiddleware.CacheEntry(response: response, ttl: 60)
    )

    let dataFile = try #require(
      FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .first { $0.pathExtension == "cache" }
    )
    let storedData = try Data(contentsOf: dataFile)
    var storedObject = try #require(
      JSONSerialization.jsonObject(with: storedData) as? [String: Any]
    )
    storedObject["statusCode"] = 201
    try JSONSerialization.data(withJSONObject: storedObject).write(to: dataFile)

    #expect(await cache.get("integrity") == nil)
    #expect(!FileManager.default.fileExists(atPath: dataFile.path))
  }

  @Test("Long cache keys retain separate disk entries")
  func longKeysDoNotCollide() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "networking-disk-cache-\(UUID().uuidString)",
      isDirectory: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }

    let cache = try DiskCacheStorage(cacheDirectory: CacheDirectoryURL(directory))
    let response = try makeResponse(bodyByteCount: 10)
    let sharedPrefix = String(repeating: "a", count: 300)
    let first = CacheKey(sharedPrefix + "-first")
    let second = CacheKey(sharedPrefix + "-second")
    let entry = CachingMiddleware.CacheEntry(response: response, ttl: 60)

    await cache.set(first, entry: entry)
    await cache.set(second, entry: entry)

    #expect(await cache.get(first) != nil)
    #expect(await cache.get(second) != nil)
  }

  @Test("Predicate invalidation removes only matching cache keys")
  func predicateInvalidationIsSelective() async throws {
    let storage = MemoryCacheStorage()
    let entry = CachingMiddleware.CacheEntry(
      response: try makeResponse(bodyByteCount: 4),
      ttl: 60
    )
    await storage.set("first", entry: entry)
    await storage.set("second", entry: entry)

    let middleware = CachingMiddleware(
      configuration: CachingMiddleware.Configuration(),
      storage: storage,
      client: NetworkClient()
    )
    await middleware.invalidateEntries(matching: {
      CacheInvalidationFlag($0.rawValue == "first")
    })

    #expect(await storage.get("first") == nil)
    #expect(await storage.get("second") != nil)
  }

  private func makeResponse(
    bodyByteCount: Int,
    headers: HTTPHeaders = [:]
  ) throws -> HTTPResponse {
    let url = try #require(URL(string: "https://cache.example.com/resource"))
    let request = HTTPRequest(method: .get, url: url)
    return HTTPResponse(
      request: request,
      status: .ok,
      headers: headers,
      body: HTTPBody(Data(repeating: 0x41, count: bodyByteCount))
    )
  }
}

private actor SemaphoreCompletionState {
  private(set) var didFirstEnter = false
  private(set) var didCancelFinish = false
  private(set) var didCancelledWaiterAcquire = false

  func firstEntered() {
    didFirstEnter = true
  }

  func cancelledFinished(acquired: Bool) {
    didCancelFinish = true
    didCancelledWaiterAcquire = acquired
  }
}
