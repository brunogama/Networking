import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AuthenticationConfiguration: Sendable {
  public let strategy: AuthenticationStrategy
  public let refreshStrategy: AuthRefreshStrategy
  public let headerName: HTTPHeaderName
  public let shouldAuthenticate: @Sendable (HTTPRequest) -> AuthenticationDecision

  public init(
    strategy: AuthenticationStrategy,
    refreshStrategy: AuthRefreshStrategy = .automatic,
    headerName: HTTPHeaderName = "Authorization",
    shouldAuthenticate: @escaping @Sendable (HTTPRequest) -> AuthenticationDecision = { _ in true }
  ) {
    self.strategy = strategy
    self.refreshStrategy = refreshStrategy
    self.headerName = headerName
    self.shouldAuthenticate = shouldAuthenticate
  }
}

public enum AuthenticationStrategy: Sendable {
  case bearerToken(any BearerTokenProvider)
  case basicAuth(username: BasicAuthUsername, password: BasicAuthPassword)
  case custom(any CustomAuthProvider)
}

public enum AuthRefreshStrategy: Sendable {
  case none
  case automatic
  case manual(@Sendable () async throws -> BearerTokenValue)

  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.none, .none), (.automatic, .automatic):
      return true
    case (.manual, .manual):
      return true
    default:
      return false
    }
  }
}

public protocol BearerTokenProvider: Sendable {
  func getCurrentToken() async throws -> BearerTokenValue?
  func refreshToken() async throws -> BearerTokenValue
}

public protocol CustomAuthProvider: Sendable {
  func authenticateRequest(_ request: HTTPRequest) async throws -> HTTPRequest
  func handleAuthenticationError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse?
}

public struct RetryConfiguration: Sendable {
  public let maxAttempts: RetryAttemptCount
  public let backoffStrategy: RetryBackoffStrategy
  public let retryCondition: @Sendable (HTTPError) -> RetryDecision
  public let delay: RetryDelay

  public init(
    maxAttempts: RetryAttemptCount = 3,
    backoffStrategy: RetryBackoffStrategy = .exponential,
    delay: RetryDelay = 1.0,
    retryCondition: @escaping @Sendable (HTTPError) -> RetryDecision = Self.defaultRetryCondition
  ) {
    self.maxAttempts = maxAttempts
    self.backoffStrategy = backoffStrategy
    self.delay = delay
    self.retryCondition = retryCondition
  }

  public static func defaultRetryCondition(_ error: HTTPError) -> RetryDecision {
    switch error.category {
    case .network(.serverUnreachable), .network(.connectionLost), .timeout:
      return true
    case .http(let status) where status.rawValue >= 500:
      return true
    default:
      return false
    }
  }
}

public enum RetryBackoffStrategy: Sendable {
  case fixed
  case linear
  case exponential
  case custom(@Sendable (RetryAttemptCount) -> RetryDelay)

  public func calculateDelay(
    for attempt: RetryAttemptCount,
    baseDelay: RetryDelay
  ) -> RetryDelay {
    switch self {
    case .fixed:
      return baseDelay
    case .linear:
      return baseDelay * Double(attempt.rawValue)
    case .exponential:
      return baseDelay * pow(2.0, Double(attempt.rawValue - 1))
    case .custom(let calculator):
      return calculator(attempt)
    }
  }
}

public struct CachingConfiguration: Sendable {
  public let policy: CachingPolicy
  public let storage: CacheStorage
  public let duration: CacheDuration
  public let shouldCache: @Sendable (HTTPRequest, HTTPResponse) -> CacheDecision

  public init(
    policy: CachingPolicy = .standard,
    storage: CacheStorage = .memory(size: .MB(50)),
    duration: CacheDuration = .ttl(300),
    shouldCache: @escaping @Sendable (HTTPRequest, HTTPResponse) -> CacheDecision = Self
      .defaultShouldCache
  ) {
    self.policy = policy
    self.storage = storage
    self.duration = duration
    self.shouldCache = shouldCache
  }

  public static func defaultShouldCache(
    _ request: HTTPRequest,
    _ response: HTTPResponse
  ) -> CacheDecision {
    CacheDecision(request.method == .get && response.status.isSuccess.rawValue)
  }
}

public enum CachingPolicy: Sendable {
  case none
  case standard
  case aggressive
  case custom(maxAge: CacheMaxAge, revalidate: CacheRevalidationFlag)
}

public enum CacheStorage: Sendable {
  case memory(size: StorageSize)
  case disk(size: StorageSize, path: CacheStoragePath?)
  case hybrid(memorySize: StorageSize, diskSize: StorageSize, path: CacheStoragePath?)
}

public enum StorageSize: Sendable {
  case KB(StorageSizeValue)
  case MB(StorageSizeValue)
  case GB(StorageSizeValue)

  public var bytes: StorageSizeBytes {
    switch self {
    case .KB(let value): return StorageSizeBytes(Int64(value.rawValue) * 1024)
    case .MB(let value): return StorageSizeBytes(Int64(value.rawValue) * 1024 * 1024)
    case .GB(let value): return StorageSizeBytes(Int64(value.rawValue) * 1024 * 1024 * 1024)
    }
  }
}

public enum CacheDuration: Sendable {
  case ttl(RequestTimeout)
  case until(Date)
  case session
  case forever
}
