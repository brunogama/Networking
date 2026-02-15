import Foundation

#if canImport(Security)
import Security
#endif

// MARK: - Platform-specific Keychain Implementation

#if canImport(Security)

/// Secure storage service using iOS/macOS Keychain for sensitive data like authentication tokens.
///
/// This is implemented as an actor to ensure thread-safe access to keychain operations.
/// All keychain operations are serialized through actor isolation.
public actor KeychainService {
  // MARK: - Configuration

  public struct Configuration: Sendable {
    /// Service identifier for keychain items
    public let service: String

    /// Access group for keychain sharing between apps
    public let accessGroup: String?

    /// Keychain accessibility level
    public let accessibility: KeychainAccessibility

    /// Whether to synchronize keychain items across devices via iCloud
    public let synchronizable: Bool

    public init(
      service: String,
      accessGroup: String? = nil,
      accessibility: KeychainAccessibility = .whenUnlockedThisDeviceOnly,
      synchronizable: Bool = false
    ) {
      self.service = service
      self.accessGroup = accessGroup
      self.accessibility = accessibility
      self.synchronizable = synchronizable
    }
  }

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

  // MARK: - Properties

  private let configuration: Configuration

  // MARK: - Initialization

  public init(configuration: Configuration) {
    self.configuration = configuration
  }

  /// Initializer with service name (creates default configuration)
  public init(service: String) {
    self.configuration = Configuration(service: service)
  }

  // MARK: - Public Methods

  /// Stores a string value securely in the keychain
  /// - Parameters:
  ///   - value: The string value to store
  ///   - key: The key to associate with the value
  /// - Throws: KeychainError if the operation fails
  public func store(_ value: String, forKey key: String) throws {
    guard let data = value.data(using: .utf8) else {
      throw KeychainError.invalidData
    }

    try store(data, forKey: key)
  }

  /// Stores data securely in the keychain
  /// - Parameters:
  ///   - data: The data to store
  ///   - key: The key to associate with the data
  /// - Throws: KeychainError if the operation fails
  public func store(_ data: Data, forKey key: String) throws {
    // Delete any existing item first
    try? delete(key)

    var query = baseQuery(forKey: key)
    query[kSecValueData] = data
    query[kSecAttrAccessible] = configuration.accessibility.rawValue

    let status = SecItemAdd(query as CFDictionary, nil)

    guard status == errSecSuccess else {
      throw KeychainError.operationFailed(status)
    }
  }

  /// Retrieves a string value from the keychain
  /// - Parameter key: The key associated with the value
  /// - Returns: The string value if found, nil otherwise
  /// - Throws: KeychainError if the operation fails
  public func retrieveString(forKey key: String) throws -> String? {
    guard let data = try retrieveData(forKey: key) else {
      return nil
    }

    guard let string = String(data: data, encoding: .utf8) else {
      throw KeychainError.invalidData
    }

    return string
  }

  /// Retrieves data from the keychain
  /// - Parameter key: The key associated with the data
  /// - Returns: The data if found, nil otherwise
  /// - Throws: KeychainError if the operation fails
  public func retrieveData(forKey key: String) throws -> Data? {
    var query = baseQuery(forKey: key)
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      return result as? Data

    case errSecItemNotFound:
      return nil

    default:
      throw KeychainError.operationFailed(status)
    }
  }

  /// Updates an existing keychain item
  /// - Parameters:
  ///   - value: The new string value
  ///   - key: The key associated with the item
  /// - Throws: KeychainError if the operation fails
  public func update(_ value: String, forKey key: String) throws {
    guard let data = value.data(using: .utf8) else {
      throw KeychainError.invalidData
    }

    try update(data, forKey: key)
  }

  /// Updates an existing keychain item
  /// - Parameters:
  ///   - data: The new data
  ///   - key: The key associated with the item
  /// - Throws: KeychainError if the operation fails
  public func update(_ data: Data, forKey key: String) throws {
    let query = baseQuery(forKey: key)
    let updateAttributes: [CFString: Any] = [
      kSecValueData: data
    ]

    let status = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)

    switch status {
    case errSecSuccess:
      return

    case errSecItemNotFound:
      // Item doesn't exist, create it instead
      try store(data, forKey: key)

    default:
      throw KeychainError.operationFailed(status)
    }
  }

  /// Deletes an item from the keychain
  /// - Parameter key: The key associated with the item to delete
  /// - Throws: KeychainError if the operation fails
  public func delete(_ key: String) throws {
    let query = baseQuery(forKey: key)

    let status = SecItemDelete(query as CFDictionary)

    switch status {
    case errSecSuccess, errSecItemNotFound:
      return  // Success or item didn't exist
    default:
      throw KeychainError.operationFailed(status)
    }
  }

  /// Checks if an item exists in the keychain
  /// - Parameter key: The key to check
  /// - Returns: True if the item exists, false otherwise
  public func exists(_ key: String) -> Bool {
    var query = baseQuery(forKey: key)
    query[kSecReturnData] = false

    let status = SecItemCopyMatching(query as CFDictionary, nil)
    return status == errSecSuccess
  }

  /// Retrieves all keys stored in the keychain for this service
  /// - Returns: Array of keys
  /// - Throws: KeychainError if the operation fails
  public func allKeys() throws -> [String] {
    var query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: configuration.service,
      kSecReturnAttributes: true,
      kSecMatchLimit: kSecMatchLimitAll,
    ]

    if let accessGroup = configuration.accessGroup {
      query[kSecAttrAccessGroup] = accessGroup
    }

    if configuration.synchronizable {
      query[kSecAttrSynchronizable] = true
    }

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      guard let items = result as? [[CFString: Any]] else {
        return []
      }

      return items.compactMap { item in
        item[kSecAttrAccount] as? String
      }

    case errSecItemNotFound:
      return []

    default:
      throw KeychainError.operationFailed(status)
    }
  }

  /// Deletes all items for this service from the keychain
  /// - Throws: KeychainError if the operation fails
  public func deleteAll() throws {
    var query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: configuration.service,
    ]

    if let accessGroup = configuration.accessGroup {
      query[kSecAttrAccessGroup] = accessGroup
    }

    if configuration.synchronizable {
      query[kSecAttrSynchronizable] = true
    }

    let status = SecItemDelete(query as CFDictionary)

    switch status {
    case errSecSuccess, errSecItemNotFound:
      return  // Success or no items to delete
    default:
      throw KeychainError.operationFailed(status)
    }
  }

  // MARK: - Private Methods

  private func baseQuery(forKey key: String) -> [CFString: Any] {
    var query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: configuration.service,
      kSecAttrAccount: key,
    ]

    if let accessGroup = configuration.accessGroup {
      query[kSecAttrAccessGroup] = accessGroup
    }

    if configuration.synchronizable {
      query[kSecAttrSynchronizable] = true
    }

    return query
  }
}

// MARK: - KeychainError

/// Errors that can occur when working with the keychain
public enum KeychainError: Error, LocalizedError {
  case operationFailed(OSStatus)
  case invalidData
  case itemNotFound
  case duplicateItem
  case userCancelled
  case authenticationFailed

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

  /// Creates a KeychainError from an OSStatus
  public static func from(status: OSStatus) -> Self {
    switch status {
    case errSecItemNotFound:
      return .itemNotFound

    case errSecDuplicateItem:
      return .duplicateItem

    case errSecUserCanceled:
      return .userCancelled

    case errSecAuthFailed:
      return .authenticationFailed

    default:
      return .operationFailed(status)
    }
  }
}

// MARK: - Secure Token Provider

/// A token provider that uses Keychain for secure storage
public final class KeychainTokenProvider: BearerTokenProvider {
  private let keychainService: KeychainService
  private let tokenKey: String
  private let refreshTokenKey: String?

  public init(
    keychainService: KeychainService,
    tokenKey: String = "access_token",
    refreshTokenKey: String? = "refresh_token"
  ) {
    self.keychainService = keychainService
    self.tokenKey = tokenKey
    self.refreshTokenKey = refreshTokenKey
  }

  /// Convenience initializer with service name
  public convenience init(
    service: String,
    tokenKey: String = "access_token",
    refreshTokenKey: String? = "refresh_token"
  ) {
    let keychain = KeychainService(service: service)
    self.init(
      keychainService: keychain,
      tokenKey: tokenKey,
      refreshTokenKey: refreshTokenKey
    )
  }

  public func getCurrentToken() async throws -> String? {
    try await keychainService.retrieveString(forKey: tokenKey)
  }

  public func refreshToken() async throws -> String {
    // This is a placeholder implementation
    // In a real implementation, you would:
    // 1. Get the refresh token from keychain
    // 2. Make a network request to refresh the access token
    // 3. Store the new tokens in keychain
    // 4. Return the new access token

    guard let refreshTokenKey = refreshTokenKey,
      let _ = try await keychainService.retrieveString(forKey: refreshTokenKey)
    else {
      throw HTTPError(category: .configuration("No refresh token available"))
    }

    // Placeholder: In practice, make HTTP request to token endpoint
    throw HTTPError(category: .configuration("Token refresh not implemented"))
  }

  /// Stores an access token securely in the keychain
  public func storeToken(_ token: String) async throws {
    try await keychainService.store(token, forKey: tokenKey)
  }

  /// Stores a refresh token securely in the keychain
  public func storeRefreshToken(_ token: String) async throws {
    guard let refreshTokenKey = refreshTokenKey else {
      throw HTTPError(category: .configuration("Refresh token key not configured"))
    }
    try await keychainService.store(token, forKey: refreshTokenKey)
  }

  /// Clears all stored tokens
  public func clearTokens() async throws {
    try await keychainService.delete(tokenKey)
    if let refreshTokenKey = refreshTokenKey {
      try await keychainService.delete(refreshTokenKey)
    }
  }
}

// MARK: - Convenience Extensions

extension KeychainService {
  /// Default keychain service for the Networking framework
  public static let `default` = KeychainService(
    configuration: Configuration(service: "Networking")
  )

  /// Creates a keychain service for a specific app
  public static func app(_ bundleIdentifier: String) -> KeychainService {
    KeychainService(
      configuration: Configuration(
        service: bundleIdentifier,
        accessibility: .whenUnlockedThisDeviceOnly
      )
    )
  }

  /// Creates a keychain service with iCloud sync enabled
  public static func synced(service: String, accessGroup: String? = nil) -> KeychainService {
    KeychainService(
      configuration: Configuration(
        service: service,
        accessGroup: accessGroup,
        accessibility: .whenUnlocked,
        synchronizable: true
      )
    )
  }
}

// MARK: - Token Management Utilities

extension KeychainTokenProvider {
  /// Factory method to create a token provider for OAuth2 flows
  public static func oauth2(
    service: String,
    clientId: String? = nil
  ) -> KeychainTokenProvider {
    let tokenKey = clientId != nil ? "\(clientId!)_access_token" : "access_token"
    let refreshKey = clientId != nil ? "\(clientId!)_refresh_token" : "refresh_token"

    return KeychainTokenProvider(
      service: service,
      tokenKey: tokenKey,
      refreshTokenKey: refreshKey
    )
  }

  /// Factory method to create a token provider for API key authentication
  public static func apiKey(service: String, keyName: String = "api_key") -> KeychainTokenProvider {
    KeychainTokenProvider(
      service: service,
      tokenKey: keyName,
      refreshTokenKey: nil
    )
  }
}

#endif  // canImport(Security)
