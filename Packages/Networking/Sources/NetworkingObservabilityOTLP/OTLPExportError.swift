import NetworkingCore

/// Export failures observable by the caller; exports never silently drop a failure.
public enum OTLPExportError: Error, Sendable, Equatable {

  case cancelled

  case transport

  case rejectedStatus(HTTPStatusCode)

  case partialRejection

  case unfinishedSpan

  case invalidTimestamp

  case invalidPayload
}
