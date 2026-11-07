/// A parsed event with optional identity, name, and retry hint.
public struct SSEEvent: Sendable, Equatable {

  public let id: SSEEventID?

  public let event: SSEEventName?

  public let data: SSEEventPayload

  public let retry: SSEReconnectDelay?

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
