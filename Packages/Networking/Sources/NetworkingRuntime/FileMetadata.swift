import Foundation
import NetworkingCore

/// Metadata information about a file.
public struct FileMetadata: Sendable, Hashable {

  public let name: FileName

  public let size: FileSize

  public let mimeType: HTTPMediaType?

  public let createdAt: Date?

  public let modifiedAt: Date?

  public let checksum: FileChecksum?

  public var fileExtension: FileExtension? {
    let components = name.rawValue.components(separatedBy: ".")
    return components.count > 1 ? components.last.map { FileExtension($0) } : nil
  }

  public init(
    name: FileName,
    size: FileSize,
    mimeType: HTTPMediaType? = nil,
    createdAt: Date? = nil,
    modifiedAt: Date? = nil,
    checksum: FileChecksum? = nil
  ) {
    self.name = name
    self.size = size
    self.mimeType = mimeType
    self.createdAt = createdAt
    self.modifiedAt = modifiedAt
    self.checksum = checksum
  }
}
