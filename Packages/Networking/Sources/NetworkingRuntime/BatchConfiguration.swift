import NetworkingCore

/// Scheduling limits for a structured batch of requests.
public struct BatchConfiguration: Sendable {

  public let maxConcurrency: BatchConcurrencyLimit

  public let cancelOnFailure: CancelOnFailureFlag

  public init(
    maxConcurrency: BatchConcurrencyLimit = 8,
    cancelOnFailure: CancelOnFailureFlag = false
  ) {
    self.maxConcurrency = maxConcurrency
    self.cancelOnFailure = cancelOnFailure
  }

  public static let `default` = Self()

  public static let serial = Self(maxConcurrency: 1)
}
