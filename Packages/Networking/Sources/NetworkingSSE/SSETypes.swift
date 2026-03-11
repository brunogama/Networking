import Foundation
import NetworkingCore

public enum SSEReconnectDelayTag: Sendable {}
public enum SSEReconnectAttemptLimitTag: Sendable {}
public enum SSEReconnectAttemptTag: Sendable {}
public enum SSERespectServerRetryTag: Sendable {}
public enum SSELastEventIDTag: Sendable {}
public enum SSEAcceptHeaderTag: Sendable {}
public enum SSEEventIDTag: Sendable {}
public enum SSEEventNameTag: Sendable {}
public enum SSEEventPayloadTag: Sendable {}

public typealias SSEReconnectDelay = BoundaryDuration<SSEReconnectDelayTag>
public typealias SSEReconnectAttemptLimit = BoundaryInt<SSEReconnectAttemptLimitTag>
public typealias SSEReconnectAttempt = BoundaryInt<SSEReconnectAttemptTag>
public typealias SSERespectServerRetry = BoundaryBool<SSERespectServerRetryTag>
public typealias SSELastEventID = BoundaryString<SSELastEventIDTag>
public typealias SSEAcceptHeader = BoundaryString<SSEAcceptHeaderTag>
public typealias SSEEventID = BoundaryString<SSEEventIDTag>
public typealias SSEEventName = BoundaryString<SSEEventNameTag>
public typealias SSEEventPayload = BoundaryString<SSEEventPayloadTag>

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

public enum SSEReconnectMode: Sendable, Equatable {
  case disabled
  case automatic(SSEReconnectPolicy)
}

public struct SSEConfiguration: Sendable, Equatable {
  public var reconnectMode: SSEReconnectMode
  public var respectServerRetry: SSERespectServerRetry
  public var lastEventID: SSELastEventID?
  public var acceptHeader: SSEAcceptHeader

  public init(
    reconnectMode: SSEReconnectMode = .automatic(.init()),
    respectServerRetry: SSERespectServerRetry = true,
    lastEventID: SSELastEventID? = nil,
    acceptHeader: SSEAcceptHeader = "text/event-stream"
  ) {
    self.reconnectMode = reconnectMode
    self.respectServerRetry = respectServerRetry
    self.lastEventID = lastEventID
    self.acceptHeader = acceptHeader
  }
}

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

public enum SSEConnectionEvent: Sendable, Equatable {
  case open
  case event(SSEEvent)
  case reconnecting(attempt: SSEReconnectAttempt, delay: SSEReconnectDelay)
  case closed
}
