import Foundation
import NetworkingCore

#if canImport(Security)
import Security

extension KeychainService {
  /// Stores a string value securely in the keychain.
  public func store(_ value: KeychainStringValue, forKey key: KeychainItemKey) throws {
    guard let data = value.rawValue.data(using: .utf8) else {
      throw KeychainError.invalidData
    }

    try store(KeychainDataValue(data), forKey: key)
  }

  /// Stores data securely in the keychain.
  public func store(_ data: KeychainDataValue, forKey key: KeychainItemKey) throws {
    try? delete(key)

    var query = itemQuery(forKey: key)
    query[kSecValueData] = data.rawValue
    query[kSecAttrAccessible] = configuration.accessibility.rawValue

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw statusError(status)
    }
  }

  /// Retrieves a string value from the keychain.
  public func retrieveString(forKey key: KeychainItemKey) throws -> KeychainStringValue? {
    guard let data = try retrieveData(forKey: key) else {
      return nil
    }

    guard let string = String(data: data.rawValue, encoding: .utf8) else {
      throw KeychainError.invalidData
    }

    return KeychainStringValue(string)
  }

  /// Retrieves data from the keychain.
  public func retrieveData(forKey key: KeychainItemKey) throws -> KeychainDataValue? {
    var query = itemQuery(forKey: key)
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      return (result as? Data).map { KeychainDataValue($0) }

    case errSecItemNotFound:
      return nil

    default:
      throw statusError(status)
    }
  }

  /// Updates an existing keychain item.
  public func update(_ value: KeychainStringValue, forKey key: KeychainItemKey) throws {
    guard let data = value.rawValue.data(using: .utf8) else {
      throw KeychainError.invalidData
    }

    try update(KeychainDataValue(data), forKey: key)
  }

  /// Updates an existing keychain item.
  public func update(_ data: KeychainDataValue, forKey key: KeychainItemKey) throws {
    let status = SecItemUpdate(
      itemQuery(forKey: key) as CFDictionary,
      [kSecValueData: data.rawValue] as CFDictionary
    )

    switch status {
    case errSecSuccess:
      return

    case errSecItemNotFound:
      try store(data, forKey: key)

    default:
      throw statusError(status)
    }
  }

  /// Deletes an item from the keychain.
  public func delete(_ key: KeychainItemKey) throws {
    let status = SecItemDelete(itemQuery(forKey: key) as CFDictionary)

    switch status {
    case errSecSuccess, errSecItemNotFound:
      return

    default:
      throw statusError(status)
    }
  }

  /// Checks if an item exists in the keychain.
  public func exists(_ key: KeychainItemKey) -> KeychainItemExistenceFlag {
    var query = itemQuery(forKey: key)
    query[kSecReturnData] = false

    let status = SecItemCopyMatching(query as CFDictionary, nil)
    return KeychainItemExistenceFlag(status == errSecSuccess)
  }

  /// Retrieves all keys stored in the keychain for this service.
  public func allKeys() throws -> [KeychainItemKey] {
    var result: AnyObject?
    let status = SecItemCopyMatching(allItemsQuery() as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      return parseKeys(from: result)

    case errSecItemNotFound:
      return []

    default:
      throw statusError(status)
    }
  }

  /// Deletes all items for this service from the keychain.
  public func deleteAll() throws {
    let status = SecItemDelete(serviceQuery() as CFDictionary)

    switch status {
    case errSecSuccess, errSecItemNotFound:
      return

    default:
      throw statusError(status)
    }
  }

  private func itemQuery(forKey key: KeychainItemKey) -> [CFString: Any] {
    var query = serviceQuery()
    query[kSecAttrAccount] = key.rawValue
    return query
  }

  private func allItemsQuery() -> [CFString: Any] {
    var query = serviceQuery()
    query[kSecReturnAttributes] = true
    query[kSecMatchLimit] = kSecMatchLimitAll
    return query
  }

  private func serviceQuery() -> [CFString: Any] {
    var query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: configuration.service.rawValue,
    ]

    if let accessGroup = configuration.accessGroup {
      query[kSecAttrAccessGroup] = accessGroup.rawValue
    }

    if configuration.synchronizable.rawValue {
      query[kSecAttrSynchronizable] = true
    }

    return query
  }

  private func parseKeys(from result: AnyObject?) -> [KeychainItemKey] {
    guard let items = result as? [[CFString: Any]] else {
      return []
    }

    return items.compactMap { item in
      (item[kSecAttrAccount] as? String).map { KeychainItemKey($0) }
    }
  }

  private func statusError(_ status: OSStatus) -> KeychainError {
    KeychainError.operationFailed(KeychainStatusCode(Int(status)))
  }
}
#endif
