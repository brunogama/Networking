import Foundation
import Testing

@testable import NetworkingTesting
@Suite("Mock Authentication Provider Tests")
struct MockAuthProviderTests {
  // MARK: - MockBearerTokenProvider Tests

  @Test("getCurrentToken returns stubbed token when set")
  func returnsConfiguredToken() async throws {
    let mock = MockBearerTokenProvider()
    await mock.stubToken("test-token-123")

    let token = try await mock.getCurrentToken()

    #expect(token == "test-token-123")
  }

  @Test("getCurrentToken returns nil when no stub set")
  func returnsNilWithoutToken() async throws {
    let mock = MockBearerTokenProvider()

    let token = try await mock.getCurrentToken()

    #expect(token == nil)
  }

  @Test("getCurrentToken throws when error stubbed")
  func throwsConfiguredLookupError() async {
    let mock = MockBearerTokenProvider()
    await mock.stubTokenFetchError(URLError(.notConnectedToInternet))

    await #expect(throws: URLError.self) {
      _ = try await mock.getCurrentToken()
    }
  }

  @Test("refreshToken returns stubbed token when set")
  func returnsConfiguredRefresh() async throws {
    let mock = MockBearerTokenProvider()
    await mock.stubRefreshToken("refresh-token-456")

    let token = try await mock.refreshToken()

    #expect(token == "refresh-token-456")
  }

  @Test("refreshToken throws when no stub set")
  func rejectsUnconfiguredRefresh() async {
    let mock = MockBearerTokenProvider()

    await #expect(throws: MockError.self) {
      _ = try await mock.refreshToken()
    }
  }

  @Test("refreshToken throws when error stubbed")
  func throwsConfiguredRefreshError() async {
    let mock = MockBearerTokenProvider()
    await mock.stubRefreshError(URLError(.timedOut))

    await #expect(throws: URLError.self) {
      _ = try await mock.refreshToken()
    }
  }

  @Test("verifyTokenFetched succeeds after token fetch")
  func verifiesTokenFetches() async throws {
    let mock = MockBearerTokenProvider()
    await mock.stubToken("token")

    _ = try await mock.getCurrentToken()

    try await mock.verifyTokenFetched(times: 1)
  }

  @Test("verifyRefreshed succeeds after refresh")
  func verifiesRefreshes() async throws {
    let mock = MockBearerTokenProvider()
    await mock.stubRefreshToken("refresh-token")

    _ = try await mock.refreshToken()

    try await mock.verifyRefreshed(times: 1)
  }

  @Test("callCount increments on each call")
  func callCount_incrementsOnEachCall() async throws {
    let mock = MockBearerTokenProvider()
    await mock.stubToken("token")
    await mock.stubRefreshToken("refresh")

    var count = await mock.callCount
    #expect(count == 0)

    _ = try await mock.getCurrentToken()
    count = await mock.callCount
    #expect(count == 1)

    _ = try await mock.refreshToken()
    count = await mock.callCount
    #expect(count == 2)

    _ = try await mock.getCurrentToken()
    count = await mock.callCount
    #expect(count == 3)
  }

  @Test("verifyNeverAccessed succeeds when no calls made")
  func verifiesNoAccess() async throws {
    let mock = MockBearerTokenProvider()

    try await mock.verifyNeverAccessed()
  }

  @Test("verifyNeverAccessed throws after any call")
  func rejectsUnexpectedAccess() async throws {
    let mock = MockBearerTokenProvider()
    await mock.stubToken("token")

    _ = try await mock.getCurrentToken()

    await #expect(throws: MockError.self) {
      try await mock.verifyNeverAccessed()
    }
  }

  @Test("reset clears all stubbed values and counts")
  func reset_clearsAllStubbedValuesAndCounts() async throws {
    let mock = MockBearerTokenProvider()
    await mock.stubToken("token")
    await mock.stubRefreshToken("refresh")
    _ = try await mock.getCurrentToken()

    await mock.reset()

    let count = await mock.callCount
    #expect(count == 0)
    let token = try await mock.getCurrentToken()
    #expect(token == nil)
  }

  @Test("getTokenFetchTimestamps records all fetch requests")
  func recordsFetchTimestamps() async throws {
    let mock = MockBearerTokenProvider()
    await mock.stubToken("token")

    _ = try await mock.getCurrentToken()
    _ = try await mock.getCurrentToken()

    let timestamps = await mock.getTokenFetchTimestamps()
    #expect(timestamps.count == 2)
  }

  @Test("getRefreshTimestamps records all refresh requests")
  func recordsRefreshTimestamps() async throws {
    let mock = MockBearerTokenProvider()
    await mock.stubRefreshToken("refresh")

    _ = try await mock.refreshToken()
    _ = try await mock.refreshToken()

    let timestamps = await mock.getRefreshTimestamps()
    #expect(timestamps.count == 2)
  }

  @Test("getTokenFetchCount returns correct count")
  func getTokenFetchCount_returnsCorrectCount() async throws {
    let mock = MockBearerTokenProvider()
    await mock.stubToken("token")

    #expect(await mock.getTokenFetchCount() == 0)

    _ = try await mock.getCurrentToken()
    #expect(await mock.getTokenFetchCount() == 1)

    _ = try await mock.getCurrentToken()
    #expect(await mock.getTokenFetchCount() == 2)
  }

  @Test("getRefreshCount returns correct count")
  func getRefreshCount_returnsCorrectCount() async throws {
    let mock = MockBearerTokenProvider()
    await mock.stubRefreshToken("refresh")

    #expect(await mock.getRefreshCount() == 0)

    _ = try await mock.refreshToken()
    #expect(await mock.getRefreshCount() == 1)

    _ = try await mock.refreshToken()
    #expect(await mock.getRefreshCount() == 2)
  }
}
