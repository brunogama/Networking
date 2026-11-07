import Foundation
import NetworkingCore

extension CachingMiddleware {
  /// Optional cache policy; every key is additionally partitioned by request headers.
  public struct Configuration: Sendable {
    /// Default freshness duration when the server supplies none.
    public let defaultTTL: CacheMaxAge
    /// Capacity supplied to convenience memory-storage factories.
    public let maxCacheSize: CacheEntryLimit?
    /// Final response eligibility predicate.
    public var shouldCache: @Sendable (HTTPRequest, HTTPResponse) -> CacheDecision
    /// Logical key customization; representation and credential partitions remain enforced.
    public var cacheKeyGenerator: @Sendable (HTTPRequest) -> CacheKey = Self.defaultCacheKey
    /// Optional freshness override.
    public var ttlCalculator: (@Sendable (HTTPRequest, HTTPResponse) -> CacheMaxAge)?
    /// Caller-supplied metadata for freshness, logical keys, and invalidation.
    public var metadataExtractor: @Sendable (HTTPRequest) -> CacheMetadata? = { _ in nil }
    /// Whether stale content is conditionally revalidated.
    public let useConditionalRequests: CacheRevalidationFlag

    /// Creates a cache policy with explicit eligibility and revalidation behavior.
    public init(
      defaultTTL: CacheMaxAge = 300,
      maxCacheSize: CacheEntryLimit? = 100,
      shouldCache: @escaping @Sendable (HTTPRequest, HTTPResponse) -> CacheDecision = Self
        .defaultShouldCache,
      useConditionalRequests: CacheRevalidationFlag = true
    ) {
      self.defaultTTL = defaultTTL
      self.maxCacheSize = maxCacheSize
      self.shouldCache = shouldCache
      self.useConditionalRequests = useConditionalRequests
    }

    /// Caches successful GET responses unless the server forbids reuse.
    public static func defaultShouldCache(
      _ request: HTTPRequest,
      _ response: HTTPResponse
    ) -> CacheDecision {
      guard request.method == .get, response.status.isSuccess.rawValue else { return false }
      let directives =
        response.headers.caseInsensitiveValue(for: "Cache-Control")?.rawValue
        .lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
      return CacheDecision(!directives.contains("no-store") && !directives.contains("no-cache"))
    }

    /// Logical request key; query order remains significant.
    public static func defaultCacheKey(_ request: HTTPRequest) -> CacheKey {
      CacheKey("\(request.method.rawValue.rawValue):\(request.url.rawValue.absoluteString)")
    }

    /// Builds a partitioned key from explicit metadata and all representation-affecting headers.
    public static func defaultIntelligentCacheKey(
      _ request: HTTPRequest,
      _ metadata: CacheMetadata?
    ) -> CacheKey {
      partitionedKey(
        metadata?.customKey ?? defaultCacheKey(request),
        request: request,
        tags: metadata?.tags ?? []
      )
    }

    static func partitionedKey(
      _ base: CacheKey,
      request: HTTPRequest,
      tags: [CacheTagName]
    ) -> CacheKey {
      let headers = request.headers.filter {
        !unpartitionedHeaders.contains($0.key.rawValue.lowercased())
      }
      .map {
        "\($0.key.rawValue.lowercased().utf8.count):\($0.key.rawValue.lowercased()):\($0.value.rawValue.utf8.count):\($0.value.rawValue)"
      }
      .sorted().joined(separator: "|")
      let tagValues = tags.map(\.rawValue).sorted().map { "\($0.utf8.count):\($0)" }.joined(
        separator: "|"
      )
      return CacheKey(
        "\(base.rawValue):headers:\(Data(headers.utf8).sha256):tags:\(Data(tagValues.utf8).sha256)"
      )
    }

    static let unpartitionedHeaders: Set<String> = [
      "if-none-match", "if-modified-since", "traceparent", "tracestate",
    ]

    static func supportsVary(_ response: HTTPResponse) -> Bool {
      let fields =
        response.headers.caseInsensitiveValue(for: "Vary")?.rawValue.lowercased()
        .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
      return !fields.contains("*") && unpartitionedHeaders.isDisjoint(with: fields)
    }

    static func responseTTL(from response: HTTPResponse) -> CacheMaxAge? {
      let directives =
        response.headers.caseInsensitiveValue(for: "Cache-Control")?.rawValue
        .lowercased().split(separator: ",") ?? []
      for directive in directives {
        let parts = directive.trimmingCharacters(in: .whitespaces).split(
          separator: "=",
          maxSplits: 1
        )
        if parts.count == 2, parts[0] == "max-age", let seconds = Double(parts[1]), seconds.isFinite
        {
          return CacheMaxAge(max(0, seconds))
        }
      }
      return expiresTTL(response)
    }

    private static func expiresTTL(_ response: HTTPResponse) -> CacheMaxAge? {
      guard let value = response.headers.caseInsensitiveValue(for: "Expires") else { return nil }
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
      return formatter.date(from: value.rawValue).map {
        CacheMaxAge(max(0, $0.timeIntervalSinceNow))
      }
    }
  }
}
