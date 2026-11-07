import Foundation
import NetworkingCore
import CryptoKit

/// Supported secure checksum algorithms for file integrity verification.
///
/// Only SHA-256 and SHA-512 are supported for security reasons.
public enum ChecksumAlgorithm: Sendable, CaseIterable {
  case sha256
  case sha512

  public var identifier: ChecksumAlgorithmName {
    switch self {
    case .sha256: return "sha256"
    case .sha512: return "sha512"
    }
  }

  public func hash(_ data: HTTPBody) -> HTTPBody {
    switch self {
    case .sha256:
      return HTTPBody(Data(SHA256.hash(data: data.rawValue)))

    case .sha512:
      return HTTPBody(Data(SHA512.hash(data: data.rawValue)))
    }
  }
}
