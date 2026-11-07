import NetworkingCore

/// A server-sent event retry delay in seconds.
public typealias SSEReconnectDelay = BoundaryDuration<SSEReconnectDelayTag>
/// Maximum number of stream reconnect attempts.
public typealias SSEReconnectAttemptLimit = BoundaryInt<SSEReconnectAttemptLimitTag>
/// The ordinal number of a stream reconnect attempt.
public typealias SSEReconnectAttempt = BoundaryInt<SSEReconnectAttemptTag>
/// Whether server retry hints influence reconnect delays.
public typealias SSERespectServerRetry = BoundaryBool<SSERespectServerRetryTag>
/// The reconnect cursor sent in the Last-Event-ID header.
public typealias SSELastEventID = BoundaryString<SSELastEventIDTag>
/// The Accept header value used for event streams.
public typealias SSEAcceptHeader = BoundaryString<SSEAcceptHeaderTag>
/// An identifier received in an event id field.
public typealias SSEEventID = BoundaryString<SSEEventIDTag>
/// The name received in an event field.
public typealias SSEEventName = BoundaryString<SSEEventNameTag>
/// Joined data fields in a server-sent event.
public typealias SSEEventPayload = BoundaryString<SSEEventPayloadTag>
