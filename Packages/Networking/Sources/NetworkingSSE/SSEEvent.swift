/// A parsed event with optional identity, name, and retry hint.
public struct SSEEvent: Sendable, Equatable {
  /// Event identifier; an empty value resets the reconnect cursor.
  public let id: SSEEventID?
  /// Event name supplied by the server, when present.
  public let event: SSEEventName?
  /// Joined data lines from the event.
  public let data: SSEEventPayload
  /// Server retry interval in seconds, when present.
  public let retry: SSEReconnectDelay?

  /// Creates an event from parsed fields.
  public init(
    id: SSEEventID? = nil,
    event: SSEEventName? = nil,
    data: SSEEventPayload,
    retry: SSEReconnectDelay? = nil
  ) {
    self.id = id
    self.event = event
    self.data = data
    self.retry = retry
  }
}
