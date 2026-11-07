import Foundation
import NetworkingCore

struct DiskCacheMetadata: Codable, Sendable {
  let key: CacheKey
  let cachedAt: Date
  let expiresAt: Date
  let etag: HTTPHeaderValue?
  let lastModified: HTTPHeaderValue?
  let tags: [CacheTagName]
  let dataSize: StorageSizeBytes
  let checksum: FileChecksum
  let compressed: Bool
}
