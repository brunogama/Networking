/// Connection, reconnection, and buffering policy for a server-sent event stream.
public struct SSEConfiguration: Sendable, Equatable {

  public var reconnectMode: SSEReconnectMode

  public var respectServerRetry: SSERespectServerRetry

  public var lastEventID: SSELastEventID?

  public var acceptHeader: SSEAcceptHeader

  public var maxBufferedEvents: Int

  public var maximumResponseBytes: Int?

  public var allowPostRequests: Bool

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
