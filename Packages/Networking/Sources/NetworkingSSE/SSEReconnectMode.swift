/// Controls whether a failed stream reconnects automatically.
public enum SSEReconnectMode: Sendable, Equatable {
  case disabled
  case automatic(SSEReconnectPolicy)
}
