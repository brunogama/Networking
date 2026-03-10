import Foundation
import NetworkingCore

#if canImport(Security)
import Security

/// Errors that can occur when working with the keychain.
public enum KeychainError: Error, LocalizedError {
  case operationFailed(KeychainStatusCode)
  case invalidData
  case itemNotFound
  case duplicateItem
  case userCancelled
  case authenticationFailed

  private static let knownStatuses: [Int: Self] = [
    Int(errSecItemNotFound): .itemNotFound,
    Int(errSecDuplicateItem): .duplicateItem,
    Int(errSecUserCanceled): .userCancelled,
    Int(errSecAuthFailed): .authenticationFailed,
  ]

  public var errorDescription: String? {
    switch self {
    case .operationFailed(let status):
      return "Keychain operation failed with status: \(status)"

    case .invalidData:
      return "Invalid data provided to keychain operation"

    case .itemNotFound:
      return "Keychain item not found"

    case .duplicateItem:
      return "Duplicate keychain item"

    case .userCancelled:
      return "User cancelled keychain operation"

    case .authenticationFailed:
      return "Keychain authentication failed"
    }
  }

  /// Creates a KeychainError from an OSStatus.
  public static func from(status: KeychainStatusCode) -> Self {
    knownStatuses[status.rawValue] ?? .operationFailed(status)
  }
}
#endif
