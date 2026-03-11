import Foundation

public enum TraceVersionTag: Sendable {}
public enum TraceIdentifierTag: Sendable {}
public enum SpanIdentifierTag: Sendable {}
public enum TraceStateKeyTag: Sendable {}
public enum TraceStateValueTag: Sendable {}
public enum TraceSpanNameTag: Sendable {}
public enum TraceAttributeKeyTag: Sendable {}
public enum TraceAttributeValueTag: Sendable {}
public enum SpanEventNameTag: Sendable {}
public enum SpanStatusMessageTag: Sendable {}

public typealias TraceVersion = BoundaryString<TraceVersionTag>
public typealias TraceIdentifier = BoundaryString<TraceIdentifierTag>
public typealias SpanIdentifier = BoundaryString<SpanIdentifierTag>
public typealias TraceStateKey = BoundaryString<TraceStateKeyTag>
public typealias TraceStateValue = BoundaryString<TraceStateValueTag>
public typealias TraceSpanName = BoundaryString<TraceSpanNameTag>
public typealias TraceAttributeKey = BoundaryString<TraceAttributeKeyTag>
public typealias TraceAttributeValue = BoundaryString<TraceAttributeValueTag>
public typealias SpanEventName = BoundaryString<SpanEventNameTag>
public typealias SpanStatusMessage = BoundaryString<SpanStatusMessageTag>
