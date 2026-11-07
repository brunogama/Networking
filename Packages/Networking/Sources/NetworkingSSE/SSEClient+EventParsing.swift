import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension SSEClient {
  func streamBytes(
    from bytes: URLSession.AsyncBytes,
    maximumResponseBytes: Int?,
    state: inout SSEConnectionState,
    continuation: SSEContinuation
  ) async throws {
    var parser = SSEParser()
    var buffer = Data()
    var sawCarriageReturn = false
    var bytesRead = 0

    for try await byte in bytes {
      if let maximumResponseBytes, bytesRead >= maximumResponseBytes {
        bytes.task.cancel()
        throw SSEStreamError.responseTooLarge
      }
      bytesRead += 1
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
    if let identifier = result.idUpdate {
      state.lastEventID = identifier.isEmpty.rawValue ? nil : SSELastEventID(identifier.rawValue)
    }

    guard let event = result.event else {
      return
    }

    try yieldEvent(.event(event), to: continuation)
  }
}
