import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension SSEClient {
  func streamBytes(
    from bytes: URLSession.AsyncBytes,
    parser: inout SSEParser,
    state: inout SSEConnectionState,
    continuation: SSEContinuation
  ) async throws {
    var buffer = Data()
    var sawCarriageReturn = false

    for try await byte in bytes {
      try consumeByte(
        byte,
        buffer: &buffer,
        sawCarriageReturn: &sawCarriageReturn,
        parser: &parser,
        state: &state,
        continuation: continuation
      )
    }

    if sawCarriageReturn || !buffer.isEmpty {
      try emitLine(
        from: &buffer,
        parser: &parser,
        state: &state,
        continuation: continuation
      )
    }

    try apply(
      result: parser.finish(),
      state: &state,
      continuation: continuation
    )
  }

  // swiftlint:disable:next function_parameter_count cyclomatic_complexity
  private func consumeByte(
    _ byte: UInt8,
    buffer: inout Data,
    sawCarriageReturn: inout Bool,
    parser: inout SSEParser,
    state: inout SSEConnectionState,
    continuation: SSEContinuation
  ) throws {
    if sawCarriageReturn {
      try emitLine(from: &buffer, parser: &parser, state: &state, continuation: continuation)
      sawCarriageReturn = false
      if byte == 0x0A { return }
    }

    switch byte {
    case 0x0D:
      sawCarriageReturn = true
    case 0x0A:
      try emitLine(from: &buffer, parser: &parser, state: &state, continuation: continuation)
    default:
      buffer.append(byte)
    }
  }

  private func emitLine(
    from buffer: inout Data,
    parser: inout SSEParser,
    state: inout SSEConnectionState,
    continuation: SSEContinuation
  ) throws {
    guard let line = String(bytes: buffer, encoding: .utf8) else {
      buffer.removeAll(keepingCapacity: true)
      return
    }
    buffer.removeAll(keepingCapacity: true)

    try apply(
      result: parser.process(line: line),
      state: &state,
      continuation: continuation
    )
  }

  private func apply(
    result: SSEDispatchResult,
    state: inout SSEConnectionState,
    continuation: SSEContinuation
  ) throws {
    if let retryHint = result.retryHint {
      state.serverRetryHint = retryHint
    }

    guard let event = result.event else {
      return
    }

    if let eventID = event.id, !eventID.isEmpty {
      state.lastEventID = SSELastEventID(eventID.rawValue)
    }

    try yieldEvent(.event(event), to: continuation)
  }
}
