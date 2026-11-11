import NetworkingCore

extension RetryMiddleware {
  /// Validated limits for additional attempts and their delays.
  public struct Configuration: Sendable {

    public let maxAttempts: RetryAttemptCount

    public let initialDelay: Duration

    public let maximumDelay: Duration

    public static let `default` = Self()

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
