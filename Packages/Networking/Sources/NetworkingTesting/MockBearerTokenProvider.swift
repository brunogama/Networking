import Foundation
import NetworkingCore
import NetworkingRuntime

/// An isolated token provider with explicit stub configuration and call history.
public actor MockBearerTokenProvider: AuthenticationMiddleware.TokenProvider, MockVerifiable {
  private var token: BearerTokenValue?
  private var refreshedToken: BearerTokenValue?
  private var tokenError: (any Error)?
  private var refreshError: (any Error)?
  private var tokenRequests: [Date] = []
  private var refreshRequests: [Date] = []

  /// Creates an unstubbed provider with empty history.
  public init() {}

  /// Records a lookup, then returns the token or throws the configured failure.
  public func getCurrentToken() throws -> BearerTokenValue? {
    tokenRequests.append(Date())
    if let tokenError { throw tokenError }
    return token
  }

  /// Records a refresh, then returns its stubbed value or throws its failure.
  public func refreshToken() throws -> BearerTokenValue {
    refreshRequests.append(Date())
    if let refreshError { throw refreshError }
    guard let refreshedToken else {
      throw MockError.notStubbed("No refresh token was configured")
    }
    return refreshedToken
  }

  /// Configures successful token lookups and clears their previous failure.
  public func stubToken(_ token: BearerTokenValue) {
    self.token = token
    tokenError = nil
  }

  /// Configures successful refreshes and clears their previous failure.
  public func stubRefreshToken(_ token: BearerTokenValue) {
    refreshedToken = token
    refreshError = nil
  }

  /// Configures lookup failures.
  public func stubTokenFetchError(_ error: any Error) { tokenError = error }

  /// Configures refresh failures.
  public func stubRefreshError(_ error: any Error) { refreshError = error }

  /// Clears all stubbed values, failures, and call history.
  public func reset() {
    token = nil
    refreshedToken = nil
    tokenError = nil
    refreshError = nil
    tokenRequests.removeAll()
    refreshRequests.removeAll()
  }

  /// The combined number of token lookup and refresh attempts.
  public var callCount: MockVerificationCount {
    MockVerificationCount(tokenRequests.count + refreshRequests.count)
  }

  /// Requires the specified number of token lookup attempts.
  public func verifyTokenFetched(times: MockVerificationCount = 1) throws(MockError) {
    let actual = MockVerificationCount(tokenRequests.count)
    guard actual == times else { throw .unexpectedCallCount(expected: times, actual: actual) }
  }

  /// Requires the specified number of refresh attempts.
  public func verifyRefreshed(times: MockVerificationCount = 1) throws(MockError) {
    let actual = MockVerificationCount(refreshRequests.count)
    guard actual == times else { throw .unexpectedCallCount(expected: times, actual: actual) }
  }

  /// Requires that no token lookup or refresh was attempted.
  public func verifyNeverAccessed() throws(MockError) {
    guard callCount == 0 else { throw .unexpectedCallCount(expected: 0, actual: callCount) }
  }

  /// Returns token lookup timestamps in call order.
  public func getTokenFetchTimestamps() -> [Date] { tokenRequests }

  /// Returns refresh timestamps in call order.
  public func getRefreshTimestamps() -> [Date] { refreshRequests }

  /// Returns the number of token lookup attempts.
  public func getTokenFetchCount() -> MockVerificationCount {
    MockVerificationCount(tokenRequests.count)
  }

  /// Returns the number of refresh attempts.
  public func getRefreshCount() -> MockVerificationCount {
    MockVerificationCount(refreshRequests.count)
  }
}
