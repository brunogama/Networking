import NetworkingCore

extension RetryMiddleware {
  /// Validated limits for additional attempts and their delays.
  public struct Configuration: Sendable {
    /// The number of attempts after the original failure; zero disables retries.
    public let maxAttempts: RetryAttemptCount
    /// The delay before the first retry.
    public let initialDelay: Duration
    /// The upper bound for exponential delays.
    public let maximumDelay: Duration

    /// Three additional attempts, starting at one second and capped at thirty seconds.
    public static let `default` = Self()

    /// Rejects negative counts, negative delays, and a maximum below the initial delay.
    public init(
      maxAttempts: RetryAttemptCount,
      initialDelay: Duration = .seconds(1),
      maximumDelay: Duration = .seconds(30)
    ) throws(HTTPError) {
      guard maxAttempts.rawValue >= 0, initialDelay >= .zero, maximumDelay >= initialDelay else {
        throw HTTPError(category: .configuration("Invalid retry limits"))
      }
      self.maxAttempts = maxAttempts
      self.initialDelay = initialDelay
      self.maximumDelay = maximumDelay
    }

    private init() {
      maxAttempts = 3
      initialDelay = .seconds(1)
      maximumDelay = .seconds(30)
    }
  }
}
