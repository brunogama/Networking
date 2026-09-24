import Foundation
import NetworkingCore
import CryptoKit

// MARK: - Supporting Types

/// Cache performance metrics
public struct CacheMetrics: Sendable {
  public let size: CacheEntryCount
  public let hitCount: CacheHitCount
  public let missCount: CacheMissCount
  public let evictionCount: CacheEvictionCount
  public let hitRatio: CacheHitRatioMetric

  public init(
    size: CacheEntryCount,
    hitCount: CacheHitCount,
    missCount: CacheMissCount,
    evictionCount: CacheEvictionCount,
    hitRatio: CacheHitRatioMetric
  ) {
    self.size = size
    self.hitCount = hitCount
    self.missCount = missCount
    self.evictionCount = evictionCount
    self.hitRatio = hitRatio
  }
}

/// Serializable version of HTTPResponse for disk storage.
struct SerializableHTTPResponse: Codable {
  let statusCode: Int
  let headers: [String: String]
  let body: Data?
  let requestURL: String

  init(from response: HTTPResponse) {
    self.statusCode = response.status.rawValue.rawValue
    self.headers = response.headers.rawValue
    self.body = response.body?.rawValue
    self.requestURL = response.request.url.absoluteString
  }

  func toHTTPResponse() -> HTTPResponse? {
    guard let url = URL(string: requestURL) else {
      return nil
    }

    let request = HTTPRequest(
      method: .get,
      url: HTTPRequestURL(url),
      headers: [:],
      body: nil,
      timeout: 30.0
    )

    return HTTPResponse(
      request: request,
      status: HTTPStatus(rawValue: statusCode),
      headers: HTTPHeaders(headers),
      body: body.map { HTTPBody($0) }
    )
  }
}

extension HTTPResponse {
  var cacheStorageSize: StorageSizeBytes {
    let headerBytes = headers.reduce(into: 0) { size, header in
      size += header.key.rawValue.utf8.count + header.value.rawValue.utf8.count
    }
    let bodyBytes = body?.rawValue.count ?? 0
    return StorageSizeBytes(Int64(headerBytes + bodyBytes))
  }
}

// MARK: - Data Extensions

extension Data {
  var sha256: String {
    let digest = CryptoKit.SHA256.hash(data: self)
    return digest.compactMap { String(format: "%02x", $0) }.joined()
  }

  func compressedForCache() -> Data? {
    try? (self as NSData).compressed(using: .zlib) as Data
  }

  func decompressedForCache() -> Data? {
    try? (self as NSData).decompressed(using: .zlib) as Data
  }
}
