import NetworkingCore

/// Export failures observable by the caller; exports never silently drop a failure.
public enum OTLPExportError: Error, Sendable, Equatable {
  /// Export was cancelled before completion.
  case cancelled
  /// URLSession could not complete the request.
  case transport
  /// The collector returned a non-successful HTTP status.
  case rejectedStatus(HTTPStatusCode)
  /// The collector reported rejecting some telemetry records.
  case partialRejection
  /// The span is still active.
  case unfinishedSpan
  /// A timestamp cannot be represented by OTLP's unsigned nanoseconds.
  case invalidTimestamp
  /// The protobuf payload or response could not be encoded or decoded.
  case invalidPayload
}
