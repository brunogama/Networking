import Foundation
import NetworkingCore

/// Metadata information about a file.
public struct FileMetadata: Sendable, Hashable {
  /// The file name.
  public let name: FileName

  /// The file size in bytes.
  public let size: FileSize

  /// The MIME type of the file.
  public let mimeType: HTTPMediaType?

  /// File creation date.
  public let createdAt: Date?

  /// File modification date.
  public let modifiedAt: Date?

  /// File checksum for integrity verification.
  public let checksum: FileChecksum?

  /// File extension.
  public var fileExtension: FileExtension? {
    let components = name.rawValue.components(separatedBy: ".")
    return components.count > 1 ? components.last.map { FileExtension($0) } : nil
  }

  /// Captures file attributes and an optional verified checksum.
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
