#if canImport(Security)
import Security

extension KeychainService {
  /// Determines when the operating system permits access to stored items.
  public enum KeychainAccessibility: Sendable {
    case whenUnlocked
    case whenUnlockedThisDeviceOnly
    case afterFirstUnlock
    case afterFirstUnlockThisDeviceOnly
    case whenPasscodeSetThisDeviceOnly

    var rawValue: CFString {
      switch self {
      case .whenUnlocked:
        return kSecAttrAccessibleWhenUnlocked

      case .whenUnlockedThisDeviceOnly:
        return kSecAttrAccessibleWhenUnlockedThisDeviceOnly

      case .afterFirstUnlock:
        return kSecAttrAccessibleAfterFirstUnlock

      case .afterFirstUnlockThisDeviceOnly:
        return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

      case .whenPasscodeSetThisDeviceOnly:
        return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
      }
    }
  }
}
#endif
