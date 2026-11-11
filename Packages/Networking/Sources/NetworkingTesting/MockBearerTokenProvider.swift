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

  public init() {}

  public func getCurrentToken() throws -> BearerTokenValue? {
    tokenRequests.append(Date())
    if let tokenError { throw tokenError }
    return token
  }

  public func refreshToken() throws -> BearerTokenValue {
    refreshRequests.append(Date())
    if let refreshError { throw refreshError }
    guard let refreshedToken else {
      throw MockError.notStubbed("No refresh token was configured")
    }
    return refreshedToken
  }

  public func stubToken(_ token: BearerTokenValue) {
    self.token = token
    tokenError = nil
  }

  public func stubRefreshToken(_ token: BearerTokenValue) {
    refreshedToken = token
    refreshError = nil
  }

  public func stubTokenFetchError(_ error: any Error) { tokenError = error }

  public func stubRefreshError(_ error: any Error) { refreshError = error }

  public func reset() {
    token = nil
    refreshedToken = nil
    tokenError = nil
    refreshError = nil
    tokenRequests.removeAll()
    refreshRequests.removeAll()
  }

  public var callCount: MockVerificationCount {
    MockVerificationCount(tokenRequests.count + refreshRequests.count)
  }

  public func verifyTokenFetched(times: MockVerificationCount = 1) throws(MockError) {
    let actual = MockVerificationCount(tokenRequests.count)
    guard actual == times else { throw .unexpectedCallCount(expected: times, actual: actual) }
  }

  public func verifyRefreshed(times: MockVerificationCount = 1) throws(MockError) {
    let actual = MockVerificationCount(refreshRequests.count)
    guard actual == times else { throw .unexpectedCallCount(expected: times, actual: actual) }
  }

  public func verifyNeverAccessed() throws(MockError) {
    guard callCount == 0 else { throw .unexpectedCallCount(expected: 0, actual: callCount) }
  }

  public func getTokenFetchTimestamps() -> [Date] { tokenRequests }

  public func getRefreshTimestamps() -> [Date] { refreshRequests }

  public func getTokenFetchCount() -> MockVerificationCount {
    MockVerificationCount(tokenRequests.count)
  }

  public func getRefreshCount() -> MockVerificationCount {
    MockVerificationCount(refreshRequests.count)
  }
}
