import Foundation
import Testing

@testable import Networking

/// Tests for mock authentication provider implementations
///
/// Covers MockBearerTokenProvider stubbing, verification, and error handling.
@Suite("Mock Authentication Provider Tests")
struct MockAuthProviderTests {

  // MARK: - MockBearerTokenProvider Tests

  @Test("getCurrentToken returns stubbed token when set")
  func getCurrentToken_returnsStubbed_whenStubSet() async throws {
    let mock = MockBearerTokenProvider()
    mock.stubToken("test-token-123")

    let token = try await mock.getCurrentToken()

    #expect(token == "test-token-123")
  }

  @Test("getCurrentToken returns nil when no stub set")
  func getCurrentToken_returnsNil_whenNoStub() async throws {
    let mock = MockBearerTokenProvider()

    let token = try await mock.getCurrentToken()

    #expect(token == nil)
  }

  @Test("getCurrentToken throws when error stubbed")
  func getCurrentToken_throws_whenErrorStubbed() async {
    let mock = MockBearerTokenProvider()
    mock.stubTokenFetchError(URLError(.notConnectedToInternet))

    await #expect(throws: URLError.self) {
      _ = try await mock.getCurrentToken()
    }
  }

  @Test("refreshToken returns stubbed token when set")
  func refreshToken_returnsStubbed_whenStubSet() async throws {
    let mock = MockBearerTokenProvider()
    mock.stubRefreshToken("refresh-token-456")

    let token = try await mock.refreshToken()

    #expect(token == "refresh-token-456")
  }

  @Test("refreshToken throws when no stub set")
  func refreshToken_throws_whenNoStub() async {
    let mock = MockBearerTokenProvider()

    await #expect(throws: MockError.self) {
      _ = try await mock.refreshToken()
    }
  }

  @Test("refreshToken throws when error stubbed")
  func refreshToken_throws_whenErrorStubbed() async {
    let mock = MockBearerTokenProvider()
    mock.stubRefreshError(URLError(.timedOut))

    await #expect(throws: URLError.self) {
      _ = try await mock.refreshToken()
    }
  }

  @Test("verifyTokenFetched succeeds after token fetch")
  func verifyTokenFetched_succeeds_afterTokenFetch() async throws {
    let mock = MockBearerTokenProvider()
    mock.stubToken("token")

    _ = try await mock.getCurrentToken()

    try mock.verifyTokenFetched(times: 1)
  }

  @Test("verifyRefreshed succeeds after refresh")
  func verifyRefreshed_succeeds_afterRefresh() async throws {
    let mock = MockBearerTokenProvider()
    mock.stubRefreshToken("refresh-token")

    _ = try await mock.refreshToken()

    try mock.verifyRefreshed(times: 1)
  }

  @Test("callCount increments on each call")
  func callCount_incrementsOnEachCall() async throws {
    let mock = MockBearerTokenProvider()
    mock.stubToken("token")
    mock.stubRefreshToken("refresh")

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
  func verifyNeverAccessed_succeeds_whenNoCallsMade() async throws {
    let mock = MockBearerTokenProvider()

    try await mock.verifyNeverAccessed()
  }

  @Test("verifyNeverAccessed throws after any call")
  func verifyNeverAccessed_throws_afterAnyCall() async throws {
    let mock = MockBearerTokenProvider()
    mock.stubToken("token")

    _ = try await mock.getCurrentToken()

    await #expect(throws: MockError.self) {
      try await mock.verifyNeverAccessed()
    }
  }

  @Test("reset clears all stubbed values and counts")
  func reset_clearsAllStubbedValuesAndCounts() async throws {
    let mock = MockBearerTokenProvider()
    mock.stubToken("token")
    mock.stubRefreshToken("refresh")
    _ = try await mock.getCurrentToken()

    mock.reset()

    let count = await mock.callCount
    #expect(count == 0)
    let token = try await mock.getCurrentToken()
    #expect(token == nil)
  }

  @Test("getTokenFetchTimestamps records all fetch requests")
  func getTokenFetchTimestamps_recordsAllFetchRequests() async throws {
    let mock = MockBearerTokenProvider()
    mock.stubToken("token")

    _ = try await mock.getCurrentToken()
    _ = try await mock.getCurrentToken()

    let timestamps = mock.getTokenFetchTimestamps()
    #expect(timestamps.count == 2)
  }

  @Test("getRefreshTimestamps records all refresh requests")
  func getRefreshTimestamps_recordsAllRefreshRequests() async throws {
    let mock = MockBearerTokenProvider()
    mock.stubRefreshToken("refresh")

    _ = try await mock.refreshToken()
    _ = try await mock.refreshToken()

    let timestamps = mock.getRefreshTimestamps()
    #expect(timestamps.count == 2)
  }

  @Test("getTokenFetchCount returns correct count")
  func getTokenFetchCount_returnsCorrectCount() async throws {
    let mock = MockBearerTokenProvider()
    mock.stubToken("token")

    #expect(mock.getTokenFetchCount() == 0)

    _ = try await mock.getCurrentToken()
    #expect(mock.getTokenFetchCount() == 1)

    _ = try await mock.getCurrentToken()
    #expect(mock.getTokenFetchCount() == 2)
  }

  @Test("getRefreshCount returns correct count")
  func getRefreshCount_returnsCorrectCount() async throws {
    let mock = MockBearerTokenProvider()
    mock.stubRefreshToken("refresh")

    #expect(mock.getRefreshCount() == 0)

    _ = try await mock.refreshToken()
    #expect(mock.getRefreshCount() == 1)

    _ = try await mock.refreshToken()
    #expect(mock.getRefreshCount() == 2)
  }
}
