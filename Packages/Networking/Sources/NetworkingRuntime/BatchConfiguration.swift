import NetworkingCore

/// Scheduling limits for a structured batch of requests.
public struct BatchConfiguration: Sendable {
  /// Maximum concurrent requests; zero or a negative value permits the whole batch.
  public let maxConcurrency: BatchConcurrencyLimit
  /// Cancels active requests and stops scheduling when a request fails.
  public let cancelOnFailure: CancelOnFailureFlag

  /// Creates scheduling limits; all started requests are joined before returning.
  public init(
    maxConcurrency: BatchConcurrencyLimit = 8,
    cancelOnFailure: CancelOnFailureFlag = false
  ) {
    self.maxConcurrency = maxConcurrency
    self.cancelOnFailure = cancelOnFailure
  }

  /// Eight concurrent requests, continuing after individual failures.
  public static let `default` = Self()
  /// One request at a time.
  public static let serial = Self(maxConcurrency: 1)
}
