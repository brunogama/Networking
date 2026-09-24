import Foundation
import NetworkingCore

#if canImport(CommonCrypto)
import CommonCrypto
#endif

struct FileTransferFileInspector: Sendable {
  private let integrityCheckEnabled: Bool
  private let checksumAlgorithm: ChecksumAlgorithm

  init(configuration: FileTransferConfiguration) {
    self.integrityCheckEnabled = configuration.enableIntegrityCheck.rawValue
    self.checksumAlgorithm = configuration.checksumAlgorithm
  }

  func metadata(for fileURL: URL) throws -> FileMetadata {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw FileTransferError.fileNotFound(path: FileSystemPath(fileURL.path))
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
    let checksum: FileChecksum?
    if integrityCheckEnabled {
      checksum = try calculateChecksum(for: fileURL)
    } else {
      checksum = nil
    }

    return FileMetadata(
      name: FileName(fileURL.lastPathComponent),
      size: FileSize(fileSize),
      mimeType: Self.mimeType(for: fileURL),
      createdAt: attributes[.creationDate] as? Date,
      modifiedAt: attributes[.modificationDate] as? Date,
      checksum: checksum
    )
  }

  private func calculateChecksum(for fileURL: URL) throws -> FileChecksum {
    #if canImport(CommonCrypto)
    let digest: [UInt8]
    switch checksumAlgorithm {
    case .sha256:
      digest = try digestFile(
        at: fileURL,
        context: CC_SHA256_CTX(),
        digestLength: Int(CC_SHA256_DIGEST_LENGTH),
        initialize: CC_SHA256_Init,
        update: CC_SHA256_Update,
        finalize: CC_SHA256_Final
      )
    case .sha512:
      digest = try digestFile(
        at: fileURL,
        context: CC_SHA512_CTX(),
        digestLength: Int(CC_SHA512_DIGEST_LENGTH),
        initialize: CC_SHA512_Init,
        update: CC_SHA512_Update,
        finalize: CC_SHA512_Final
      )
    }
    return FileChecksum(digest.map { String(format: "%02x", $0) }.joined())
    #else
    let data = HTTPBody(try Data(contentsOf: fileURL))
    let digest = checksumAlgorithm.hash(data)
    return FileChecksum(digest.rawValue.map { String(format: "%02x", $0) }.joined())
    #endif
  }

  #if canImport(CommonCrypto)
  // swiftlint:disable:next function_parameter_count
  private func digestFile<Context>(
    at fileURL: URL,
    context initialContext: Context,
    digestLength: Int,
    initialize: (UnsafeMutablePointer<Context>?) -> Int32,
    update: (UnsafeMutablePointer<Context>?, UnsafeRawPointer?, CC_LONG) -> Int32,
    finalize: (UnsafeMutablePointer<UInt8>?, UnsafeMutablePointer<Context>?) -> Int32
  ) throws -> [UInt8] {
    var context = initialContext
    _ = initialize(&context)
    let file = try FileHandle(forReadingFrom: fileURL)
    defer { try? file.close() }

    while let chunk = try file.read(upToCount: 64 * 1024), !chunk.isEmpty {
      chunk.withUnsafeBytes { bytes in
        _ = update(&context, bytes.baseAddress, CC_LONG(chunk.count))
      }
    }

    var digest = [UInt8](repeating: 0, count: digestLength)
    _ = finalize(&digest, &context)
    return digest
  }
  #endif

  private static func mimeType(for fileURL: URL) -> HTTPMediaType? {
    let mimeTypes: [String: String] = [
      "gif": "image/gif",
      "html": "text/html",
      "jpeg": "image/jpeg",
      "jpg": "image/jpeg",
      "json": "application/json",
      "mov": "video/quicktime",
      "mp3": "audio/mpeg",
      "mp4": "video/mp4",
      "pdf": "application/pdf",
      "png": "image/png",
      "txt": "text/plain",
      "wav": "audio/wav",
      "xml": "application/xml",
      "zip": "application/zip",
    ]

    return mimeTypes[fileURL.pathExtension.lowercased()].map { HTTPMediaType($0) }
  }
}
