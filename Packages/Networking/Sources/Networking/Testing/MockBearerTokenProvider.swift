import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Mock implementation of BearerTokenProvider for testing
///
/// Provides stubbing and verification capabilities for bearer token authentication flows.
/// Thread-safe via DispatchQueue with concurrent reads and barrier writes.
///
/// ## Usage Example
/// ```swift
/// let mock = MockBearerTokenProvider()
/// mock.stubToken("access-token-123")
/// mock.stubRefreshToken("refresh-token-456")
///
/// let token = try await mock.getCurrentToken()
/// XCTAssertEqual(token, "access-token-123")
///
/// try mock.verifyTokenFetched(times: 1)
/// try mock.verifyCalledOnce()
/// ```
///
/// ## Error Stubbing
/// ```swift
/// mock.stubTokenFetchError(URLError(.notConnectedToInternet))
/// do {
///   _ = try await mock.getCurrentToken()
///   XCTFail("Should have thrown")
/// } catch {
///   XCTAssert(error is URLError)
/// }
/// ```
///
/// - Note: `@unchecked Sendable` justification:
///   1. Test-only code, not production
///   2. Mutable state protected by `DispatchQueue.concurrent` with barrier writes
///   3. All public methods synchronize access through concurrent queue
///   4. Call count tracking uses atomic operations via queue
///   5. Acceptable tradeoff for test ergonomics (same pattern as MockNetworkClient)
public final class MockBearerTokenProvider: BearerTokenProvider,
  MockVerifiable,
  @unchecked Sendable
{
  // MARK: - Thread Safety

  private let queue = DispatchQueue(label: "mock.bearer.token.provider", attributes: .concurrent)

  // MARK: - State Tracking

  private var stubbedToken: String?
  private var stubbedRefreshToken: String?
  private var tokenFetchError: Error?
  private var refreshError: Error?
  private var tokenFetchCount: Int = 0
  private var refreshCount: Int = 0
  private var capturedTokenRequests: [Date] = []
  private var capturedRefreshRequests: [Date] = []

  // MARK: - Initialization

  public init() {}

  // MARK: - BearerTokenProvider Protocol

  /// Get the current bearer token
  ///
  /// Returns stubbed token or throws stubbed error if configured.
  /// Increments token fetch count and captures request timestamp.
  ///
  /// - Returns: Stubbed token string, or nil if not stubbed
  /// - Throws: Stubbed error if configured via `stubTokenFetchError(_:)`
  public func getCurrentToken() async throws -> String? {
    queue.sync(flags: .barrier) {
      tokenFetchCount += 1
      capturedTokenRequests.append(Date())
    }

    // Check for stubbed error first
    if let error = queue.sync(execute: { tokenFetchError }) {
      throw error
    }

    return queue.sync { stubbedToken }
  }

  /// Refresh the bearer token
  ///
  /// Returns stubbed refresh token or throws stubbed error if configured.
  /// Increments refresh count and captures request timestamp.
  ///
  /// - Returns: Stubbed refresh token string
  /// - Throws: Stubbed error if configured, or `MockError.notStubbed` if no token stubbed
  public func refreshToken() async throws -> String {
    queue.sync(flags: .barrier) {
      refreshCount += 1
      capturedRefreshRequests.append(Date())
    }

    // Check for stubbed error first
    if let error = queue.sync(execute: { refreshError }) {
      throw error
    }

    // Return stubbed refresh token or throw if not stubbed
    guard let token = queue.sync(execute: { stubbedRefreshToken }) else {
      throw MockError.notStubbed("refreshToken() called but no refresh token stubbed")
    }

    return token
  }

  // MARK: - Stubbing Methods

  /// Stub the token to be returned by `getCurrentToken()`
  ///
  /// - Parameter token: Token string to return
  public func stubToken(_ token: String) {
    queue.sync(flags: .barrier) {
      stubbedToken = token
    }
  }

  /// Stub the token to be returned by `refreshToken()`
  ///
  /// - Parameter token: Refresh token string to return
  public func stubRefreshToken(_ token: String) {
    queue.sync(flags: .barrier) {
      stubbedRefreshToken = token
    }
  }

  /// Stub an error to be thrown by `getCurrentToken()`
  ///
  /// - Parameter error: Error to throw when token is fetched
  public func stubTokenFetchError(_ error: Error) {
    queue.sync(flags: .barrier) {
      tokenFetchError = error
    }
  }

  /// Stub an error to be thrown by `refreshToken()`
  ///
  /// - Parameter error: Error to throw when token is refreshed
  public func stubRefreshError(_ error: Error) {
    queue.sync(flags: .barrier) {
      refreshError = error
    }
  }

  /// Remove all stubbed values and errors
  public func reset() {
    queue.sync(flags: .barrier) {
      stubbedToken = nil
      stubbedRefreshToken = nil
      tokenFetchError = nil
      refreshError = nil
      tokenFetchCount = 0
      refreshCount = 0
      capturedTokenRequests.removeAll()
      capturedRefreshRequests.removeAll()
    }
  }

  // MARK: - MockVerifiable Protocol

  /// Total number of calls made to this mock (token fetch + refresh)
  ///
  /// Conforms to `MockVerifiable` protocol for shared verification methods.
  public var callCount: Int {
    queue.sync { tokenFetchCount + refreshCount }
  }

  // MARK: - Verification Methods

  /// Verify that `getCurrentToken()` was called a specific number of times
  ///
  /// - Parameter times: Expected number of token fetch calls (default: 1)
  /// - Throws: `MockError.unexpectedCallCount` if actual count doesn't match
  public func verifyTokenFetched(times: Int = 1) throws {
    let actual = queue.sync { tokenFetchCount }
    guard actual == times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actual)
    }
  }

  /// Verify that `refreshToken()` was called a specific number of times
  ///
  /// - Parameter times: Expected number of refresh calls (default: 1)
  /// - Throws: `MockError.unexpectedCallCount` if actual count doesn't match
  public func verifyRefreshed(times: Int = 1) throws {
    let actual = queue.sync { refreshCount }
    guard actual == times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actual)
    }
  }

  /// Verify that neither token fetch nor refresh was called
  ///
  /// - Throws: `MockError.unexpectedCallCount` if any calls were made
  public func verifyNeverAccessed() throws {
    let total = callCount
    guard total == 0 else {
      throw MockError.unexpectedCallCount(expected: 0, actual: total)
    }
  }

  // MARK: - Request Inspection

  /// Get the timestamps of all token fetch requests
  ///
  /// - Returns: Array of dates when `getCurrentToken()` was called
  public func getTokenFetchTimestamps() -> [Date] {
    queue.sync { capturedTokenRequests }
  }

  /// Get the timestamps of all refresh token requests
  ///
  /// - Returns: Array of dates when `refreshToken()` was called
  public func getRefreshTimestamps() -> [Date] {
    queue.sync { capturedRefreshRequests }
  }

  /// Get the count of token fetch requests
  ///
  /// - Returns: Number of times `getCurrentToken()` was called
  public func getTokenFetchCount() -> Int {
    queue.sync { tokenFetchCount }
  }

  /// Get the count of refresh token requests
  ///
  /// - Returns: Number of times `refreshToken()` was called
  public func getRefreshCount() -> Int {
    queue.sync { refreshCount }
  }
}
