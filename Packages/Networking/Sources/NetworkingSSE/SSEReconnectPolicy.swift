/// Exponential backoff limits for automatic stream reconnection.
public struct SSEReconnectPolicy: Sendable, Equatable {

  public var initialDelay: SSEReconnectDelay

  public var maxDelay: SSEReconnectDelay

  public var maxAttempts: SSEReconnectAttemptLimit?

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
