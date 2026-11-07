/// Exponential backoff limits for automatic stream reconnection.
public struct SSEReconnectPolicy: Sendable, Equatable {
  /// Initial retry delay in seconds.
  public var initialDelay: SSEReconnectDelay
  /// Upper bound on client and server retry delays.
  public var maxDelay: SSEReconnectDelay
  /// Maximum retry attempts, or nil for no attempt limit.
  public var maxAttempts: SSEReconnectAttemptLimit?

  /// Configures the initial delay, delay cap, and optional retry limit.
  public init(
    initialDelay: SSEReconnectDelay = 3.0,
    maxDelay: SSEReconnectDelay = 30.0,
    maxAttempts: SSEReconnectAttemptLimit? = nil
  ) {
    self.initialDelay = initialDelay
    self.maxDelay = maxDelay
    self.maxAttempts = maxAttempts
  }
}
