/// Connection, reconnection, and buffering policy for a server-sent event stream.
public struct SSEConfiguration: Sendable, Equatable {
  /// Whether and how to retry a disconnected stream.
  public var reconnectMode: SSEReconnectMode
  /// Whether server retry fields override the client backoff delay.
  public var respectServerRetry: SSERespectServerRetry
  /// Last received event identifier sent on the first connection.
  public var lastEventID: SSELastEventID?
  /// Accept header value sent when opening the stream.
  public var acceptHeader: SSEAcceptHeader
  /// Maximum events waiting for a consumer before the stream fails.
  public var maxBufferedEvents: Int
  /// Optional maximum total response bytes consumed by one connection.
  public var maximumResponseBytes: Int?
  /// Explicitly permits POST only when automatic reconnection is disabled.
  public var allowPostRequests: Bool

  /// Configures event buffering and reconnection; buffer capacity is at least one.
  public init(
    reconnectMode: SSEReconnectMode = .automatic(.init()),
    respectServerRetry: SSERespectServerRetry = true,
    lastEventID: SSELastEventID? = nil,
    acceptHeader: SSEAcceptHeader = "text/event-stream",
    maxBufferedEvents: Int = 256,
    maximumResponseBytes: Int? = nil,
    allowPostRequests: Bool = false
  ) {
    self.reconnectMode = reconnectMode
    self.respectServerRetry = respectServerRetry
    self.lastEventID = lastEventID
    self.acceptHeader = acceptHeader
    self.maxBufferedEvents = max(1, maxBufferedEvents)
    self.maximumResponseBytes = maximumResponseBytes
    self.allowPostRequests = allowPostRequests
  }
}
