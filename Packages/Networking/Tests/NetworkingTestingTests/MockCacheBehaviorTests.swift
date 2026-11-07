import Foundation
import NetworkingCore
import Testing

@testable import NetworkingRuntime
import NetworkingTesting

struct MockCacheBehaviorTests {
  @Test("Tag invalidation removes only entries with a matching tag")
  func removesTaggedEntries() async throws {
    let storage = MockCacheStorage()
    var tagged = try entry()
    tagged.tags = ["users"]
    await storage.stub(key: "users", entry: tagged)
    await storage.stub(key: "settings", entry: try entry())

    await storage.removeByTags(["users"])

    #expect(await storage.get("users") == nil)
    #expect(await storage.get("settings") != nil)
  }

  @Test("Wildcard invalidation treats punctuation literally and matches complete keys")
  func matchesWholeKeys() async throws {
    let storage = MockCacheStorage()
    for key: CacheKey in ["user.1", "userX1", "prefix-user.1", "user.1-suffix"] {
      await storage.stub(key: key, entry: try entry())
    }

    await storage.removeByPattern("user.?")

    #expect(await storage.get("user.1") == nil)
    #expect(await storage.getStorageCount() == 3)
    #expect(await storage.get("userX1") != nil)
    #expect(await storage.get("prefix-user.1") != nil)
    #expect(await storage.get("user.1-suffix") != nil)
  }

  @Test("Fresh lookups reject stale entries while revalidation retains their validators")
  func separatesFreshnessFromRevalidation() async throws {
    let storage = MockCacheStorage()
    await storage.stub(key: "expired", entry: try entry(ttl: 0))

    #expect(await storage.getForRevalidation("expired") != nil)
    let boundary: any HTTPResponseCacheStorage = storage
    #expect(await boundary.getForRevalidation("expired") != nil)
    #expect(await storage.get("expired") == nil)
  }

  private func entry(ttl: CacheMaxAge = 60) throws -> CachingMiddleware.CacheEntry {
    let url = try #require(URL(string: "https://mock.test/cache"))
    let response = HTTPResponse(
      request: HTTPRequest(method: .get, url: url),
      status: .ok,
      body: HTTPBody?.none
    )
    return CachingMiddleware.CacheEntry(response: response, ttl: ttl, etag: "v1")
  }
}
