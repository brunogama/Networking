import Foundation
import XCTest

@testable import NetworkingRuntime
import NetworkingDSL
import NetworkingRuntimeDSL
import NetworkingTesting

/// Comprehensive tests for KeychainService secure credential storage
final class KeychainServiceTests: XCTestCase {
    // MARK: - Test Infrastructure

    private var sut: KeychainService!
    private var testService: String!

    override func setUp() {
        super.setUp()
        testService = "com.modernnetworking.tests.\(UUID().uuidString)"
        sut = KeychainService(service: testService)
    }

    override func tearDown() async throws {
        // Clean up test keychain items
        try? await sut.deleteAll()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Configuration Tests

    func testConfigurationInitialization() {
        let config = KeychainService.Configuration(
            service: testService,
            accessGroup: nil,
            accessibility: .whenUnlockedThisDeviceOnly,
            synchronizable: false
        )

        XCTAssertEqual(config.service, testService)
        XCTAssertNil(config.accessGroup)
        XCTAssertEqual(config.accessibility, .whenUnlockedThisDeviceOnly)
        XCTAssertFalse(config.synchronizable)
    }

    func testConfigurationWithAccessGroup() {
        let config = KeychainService.Configuration(
            service: testService,
            accessGroup: "test.group",
            accessibility: .whenUnlocked,
            synchronizable: true
        )

        XCTAssertEqual(config.accessGroup, "test.group")
        XCTAssertEqual(config.accessibility, .whenUnlocked)
        XCTAssertTrue(config.synchronizable)
    }

    func testAccessibilityLevels() {
        let levels: [KeychainService.KeychainAccessibility] = [
            .whenUnlocked,
            .whenUnlockedThisDeviceOnly,
            .afterFirstUnlock,
            .afterFirstUnlockThisDeviceOnly,
            .whenPasscodeSetThisDeviceOnly,
        ]

        for level in levels {
            let config = KeychainService.Configuration(
                service: testService,
                accessibility: level
            )
            XCTAssertEqual(config.accessibility, level)
        }
    }

    func testServiceInitialization() {
        let service = KeychainService(service: testService)
        XCTAssertNotNil(service)
    }

    func testConfigurationBasedInitialization() {
        let config = KeychainService.Configuration(
            service: testService,
            accessibility: .afterFirstUnlock
        )
        let service = KeychainService(configuration: config)
        XCTAssertNotNil(service)
    }

    // MARK: - String Storage Tests

    func testStoreStringValue() async throws {
        let key = "testKey"
        let value = "testValue"

        try await sut.store(value, forKey: key)

        let retrieved = try await sut.retrieveString(forKey: key)
        XCTAssertEqual(retrieved, value)
    }

    func testStoreEmptyString() async throws {
        let key = "emptyKey"
        let value = ""

        try await sut.store(value, forKey: key)

        let retrieved = try await sut.retrieveString(forKey: key)
        XCTAssertEqual(retrieved, value)
    }

    func testStoreUnicodeString() async throws {
        let key = "unicodeKey"
        let value = "Test with unicode: cafe\u{0301} and symbols"

        try await sut.store(value, forKey: key)

        let retrieved = try await sut.retrieveString(forKey: key)
        XCTAssertEqual(retrieved, value)
    }

    func testStoreLongString() async throws {
        let key = "longKey"
        let value = String(repeating: "a", count: 10000)

        try await sut.store(value, forKey: key)

        let retrieved = try await sut.retrieveString(forKey: key)
        XCTAssertEqual(retrieved, value)
    }

    func testOverwriteExistingValue() async throws {
        let key = "overwriteKey"
        try await sut.store("original", forKey: key)

        try await sut.store("updated", forKey: key)

        let retrieved = try await sut.retrieveString(forKey: key)
        XCTAssertEqual(retrieved, "updated")
    }

    // MARK: - Data Storage Tests

    func testStoreData() async throws {
        let key = "dataKey"
        let data = Data([0x01, 0x02, 0x03, 0x04])

        try await sut.store(data, forKey: key)

        let retrieved = try await sut.retrieveData(forKey: key)
        XCTAssertEqual(retrieved, data)
    }

    func testStoreLargeData() async throws {
        let key = "largeDataKey"
        let data = Data(repeating: 0xAB, count: 100_000)

        try await sut.store(data, forKey: key)

        let retrieved = try await sut.retrieveData(forKey: key)
        XCTAssertEqual(retrieved, data)
    }

    func testStoreEmptyData() async throws {
        let key = "emptyDataKey"
        let data = Data()

        try await sut.store(data, forKey: key)

        let retrieved = try await sut.retrieveData(forKey: key)
        XCTAssertEqual(retrieved, data)
    }

    // MARK: - Retrieval Tests

    func testRetrieveNonExistentKeyReturnsNil() async throws {
        let retrieved = try await sut.retrieveString(forKey: "nonexistent")
        XCTAssertNil(retrieved)
    }

    func testRetrieveDataNonExistentKeyReturnsNil() async throws {
        let retrieved = try await sut.retrieveData(forKey: "nonexistent")
        XCTAssertNil(retrieved)
    }

    // MARK: - Update Tests

    func testUpdateExistingString() async throws {
        let key = "updateKey"
        try await sut.store("original", forKey: key)

        try await sut.update("updated", forKey: key)

        let retrieved = try await sut.retrieveString(forKey: key)
        XCTAssertEqual(retrieved, "updated")
    }

    func testUpdateNonExistentKeyCreatesItem() async throws {
        let key = "newUpdateKey"

        try await sut.update("newValue", forKey: key)

        let retrieved = try await sut.retrieveString(forKey: key)
        XCTAssertEqual(retrieved, "newValue")
    }

    func testUpdateData() async throws {
        let key = "updateDataKey"
        try await sut.store(Data([0x01]), forKey: key)

        try await sut.update(Data([0x02, 0x03]), forKey: key)

        let retrieved = try await sut.retrieveData(forKey: key)
        XCTAssertEqual(retrieved, Data([0x02, 0x03]))
    }

    // MARK: - Delete Tests

    func testDeleteExistingKey() async throws {
        let key = "deleteKey"
        try await sut.store("value", forKey: key)

        try await sut.delete(key)

        let retrieved = try await sut.retrieveString(forKey: key)
        XCTAssertNil(retrieved)
    }

    func testDeleteNonExistentKeyDoesNotThrow() async throws {
        do {
            try await sut.delete("nonexistent")
        } catch {
            XCTFail("delete should not throw for non-existent key: \(error)")
        }
    }

    // MARK: - Exists Tests

    func testExistsReturnsTrueForExistingKey() async throws {
        let key = "existsKey"
        try await sut.store("value", forKey: key)

        let exists = await sut.exists(key)
        XCTAssertTrue(exists)
    }

    func testExistsReturnsFalseForNonExistentKey() async {
        let exists = await sut.exists("nonexistent")
        XCTAssertFalse(exists)
    }

    // MARK: - All Keys Tests

    func testAllKeysReturnsStoredKeys() async throws {
        try await sut.store("value1", forKey: "key1")
        try await sut.store("value2", forKey: "key2")
        try await sut.store("value3", forKey: "key3")

        let keys = try await sut.allKeys()

        XCTAssertEqual(Set(keys), Set(["key1", "key2", "key3"]))
    }

    func testAllKeysReturnsEmptyArrayWhenNoItems() async throws {
        let keys = try await sut.allKeys()
        XCTAssertTrue(keys.isEmpty)
    }

    // MARK: - Delete All Tests

    func testDeleteAllDoesNotThrow() async throws {
        // Store some items first
        try await sut.store("value1", forKey: "deleteAllKey1")
        try await sut.store("value2", forKey: "deleteAllKey2")

        // deleteAll should not throw
        do {
            try await sut.deleteAll()
        } catch {
            XCTFail("deleteAll should not throw: \(error)")
        }
    }

    func testDeleteAllDoesNotThrowWhenEmpty() async throws {
        do {
            try await sut.deleteAll()
        } catch {
            XCTFail("deleteAll should not throw when empty: \(error)")
        }
    }

    // MARK: - KeychainError Tests

    func testKeychainErrorDescriptions() {
        let invalidDataError = KeychainError.invalidData
        XCTAssertNotNil(invalidDataError.errorDescription)
        XCTAssertTrue(invalidDataError.errorDescription?.contains("Invalid") ?? false)

        let itemNotFoundError = KeychainError.itemNotFound
        XCTAssertNotNil(itemNotFoundError.errorDescription)
        XCTAssertTrue(itemNotFoundError.errorDescription?.contains("not found") ?? false)

        let duplicateItemError = KeychainError.duplicateItem
        XCTAssertNotNil(duplicateItemError.errorDescription)

        let userCancelledError = KeychainError.userCancelled
        XCTAssertNotNil(userCancelledError.errorDescription)

        let authFailedError = KeychainError.authenticationFailed
        XCTAssertNotNil(authFailedError.errorDescription)
    }

    func testKeychainErrorFromStatus() {
        let notFoundError = KeychainError.from(status: errSecItemNotFound)
        if case .itemNotFound = notFoundError {
            // Success
        } else {
            XCTFail("Expected itemNotFound error")
        }

        let duplicateError = KeychainError.from(status: errSecDuplicateItem)
        if case .duplicateItem = duplicateError {
            // Success
        } else {
            XCTFail("Expected duplicateItem error")
        }

        let userCancelledError = KeychainError.from(status: errSecUserCanceled)
        if case .userCancelled = userCancelledError {
            // Success
        } else {
            XCTFail("Expected userCancelled error")
        }

        let authFailedError = KeychainError.from(status: errSecAuthFailed)
        if case .authenticationFailed = authFailedError {
            // Success
        } else {
            XCTFail("Expected authenticationFailed error")
        }

        let unknownError = KeychainError.from(status: -12345)
        if case let .operationFailed(status) = unknownError {
            XCTAssertEqual(status, -12345)
        } else {
            XCTFail("Expected operationFailed error")
        }
    }

    // MARK: - Static Factory Tests

    func testDefaultKeychainService() {
        let service = KeychainService.default
        XCTAssertNotNil(service)
    }

    func testAppKeychainService() {
        let service = KeychainService.app("com.example.test")
        XCTAssertNotNil(service)
    }

    func testSyncedKeychainService() {
        let service = KeychainService.synced(service: "test.service")
        XCTAssertNotNil(service)
    }

    // MARK: - KeychainTokenProvider Tests

    func testKeyingTokenProviderInitialization() {
        let provider = KeychainTokenProvider(
            keychainService: sut,
            tokenKey: "access_token",
            refreshTokenKey: "refresh_token"
        )
        XCTAssertNotNil(provider)
    }

    func testTokenProviderConvenienceInitialization() {
        let provider = KeychainTokenProvider(service: testService)
        XCTAssertNotNil(provider)
    }

    func testTokenProviderStoreAndRetrieveToken() async throws {
        let provider = KeychainTokenProvider(keychainService: sut)

        try await provider.storeToken("test_access_token")

        let retrievedToken = try await provider.getCurrentToken()
        XCTAssertEqual(retrievedToken, "test_access_token")
    }

    func testTokenProviderStoreRefreshToken() async throws {
        let provider = KeychainTokenProvider(
            keychainService: sut,
            refreshTokenKey: "refresh_token"
        )

        try await provider.storeRefreshToken("test_refresh_token")

        let retrieved = try await sut.retrieveString(forKey: "refresh_token")
        XCTAssertEqual(retrieved, "test_refresh_token")
    }

    func testTokenProviderClearTokens() async throws {
        let provider = KeychainTokenProvider(
            keychainService: sut,
            tokenKey: "access_token",
            refreshTokenKey: "refresh_token"
        )
        try await provider.storeToken("access")
        try await provider.storeRefreshToken("refresh")

        try await provider.clearTokens()

        let accessToken = try await provider.getCurrentToken()
        XCTAssertNil(accessToken)
        let refreshToken = try await sut.retrieveString(forKey: "refresh_token")
        XCTAssertNil(refreshToken)
    }

    func testTokenProviderOAuth2Factory() {
        let provider = KeychainTokenProvider.oauth2(service: testService)
        XCTAssertNotNil(provider)
    }

    func testTokenProviderOAuth2FactoryWithClientId() {
        let provider = KeychainTokenProvider.oauth2(service: testService, clientId: "client123")
        XCTAssertNotNil(provider)
    }

    func testTokenProviderApiKeyFactory() {
        let provider = KeychainTokenProvider.apiKey(service: testService)
        XCTAssertNotNil(provider)
    }

    // MARK: - Sequential Access Tests

    func testSequentialWriteAccess() async throws {
        let iterations = 10

        for i in 0 ..< iterations {
            try await sut.store("value\(i)", forKey: "sequential\(i)")
        }

        // Verify all values are retrievable
        for i in 0 ..< iterations {
            let value = try await sut.retrieveString(forKey: "sequential\(i)")
            XCTAssertEqual(value, "value\(i)")
        }
    }

    func testSequentialReadWriteAccess() async throws {
        let key = "sharedKey"
        try await sut.store("initial", forKey: key)

        let iterations = 10

        for i in 0 ..< iterations {
            if i % 2 == 0 {
                try await sut.store("value\(i)", forKey: key)
            } else {
                _ = try await sut.retrieveString(forKey: key)
            }
        }

        // Should be able to retrieve some value
        let finalValue = try await sut.retrieveString(forKey: key)
        XCTAssertNotNil(finalValue)
    }
}
