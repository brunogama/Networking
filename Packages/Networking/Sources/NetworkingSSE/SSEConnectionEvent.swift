/// A connection lifecycle transition or a received server-sent event.
public enum SSEConnectionEvent: Sendable, Equatable {
  case open
  case event(SSEEvent)
  case reconnecting(attempt: SSEReconnectAttempt, delay: SSEReconnectDelay)
  case closed
}
