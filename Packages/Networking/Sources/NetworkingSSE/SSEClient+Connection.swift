import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct SSEOpenedConnection {
  let request: HTTPRequest
  let response: HTTPResponse
  let rawResponse: HTTPURLResponse
  let bytes: URLSession.AsyncBytes
}

extension SSEClient {
  func consumeConnectionAttempt(
    for request: HTTPRequest,
    configuration: SSEConfiguration,
    state: inout SSEConnectionState,
    continuation: SSEContinuation
  ) async throws {
    let connection = try await openConnection(
      for: request,
      configuration: configuration,
      state: state
    )

    continuation.yield(.open)
    try await streamEvents(
      from: connection,
      state: &state,
      continuation: continuation
    )
  }

  private func openConnection(
    for request: HTTPRequest,
    configuration: SSEConfiguration,
    state: SSEConnectionState
  ) async throws -> SSEOpenedConnection {
    let processedRequest = try await applyRequestMiddlewares(request)
    let urlRequest = try buildURLRequest(
      from: processedRequest,
      configuration: configuration,
      state: state
    )
    let (bytes, response) = try await fetchResponse(
      for: urlRequest,
      request: processedRequest
    )
    let connection = try makeOpenedConnection(
      bytes: bytes,
      response: response,
      request: processedRequest
    )

    try validateInitialResponse(connection.response, rawResponse: connection.rawResponse)
    return connection
  }

  private func fetchResponse(
    for urlRequest: URLRequest,
    request: HTTPRequest
  ) async throws -> (URLSession.AsyncBytes, URLResponse) {
    do {
      return try await session.bytes(for: urlRequest)
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as URLError {
      throw SSEAttemptFailure(
        error: mapURLError(error, for: request),
        openedConnection: false
      )
    } catch {
      throw SSEAttemptFailure(
        error: wrapUnexpectedError(error, for: request),
        openedConnection: false
      )
    }
  }

  private func makeOpenedConnection(
    bytes: URLSession.AsyncBytes,
    response: URLResponse,
    request: HTTPRequest
  ) throws -> SSEOpenedConnection {
    guard let rawResponse = response as? HTTPURLResponse else {
      throw SSEAttemptFailure(
        error: HTTPError.network(.serverUnreachable, request: request),
        openedConnection: false
      )
    }

    let metadata = HTTPResponse(
      request: request,
      httpURLResponse: rawResponse,
      body: nil
    )

    return SSEOpenedConnection(
      request: request,
      response: metadata,
      rawResponse: rawResponse,
      bytes: bytes
    )
  }

  private func streamEvents(
    from connection: SSEOpenedConnection,
    state: inout SSEConnectionState,
    continuation: SSEContinuation
  ) async throws {
    var parser = SSEParser()

    do {
      try await streamBytes(
        from: connection.bytes,
        parser: &parser,
        state: &state,
        continuation: continuation
      )
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as URLError {
      throw SSEAttemptFailure(
        error: mapURLError(error, for: connection.request),
        openedConnection: true
      )
    } catch {
      throw SSEAttemptFailure(
        error: wrapUnexpectedError(error, for: connection.request),
        openedConnection: true
      )
    }
  }

  private func streamBytes(
    from bytes: URLSession.AsyncBytes,
    parser: inout SSEParser,
    state: inout SSEConnectionState,
    continuation: SSEContinuation
  ) async throws {
    let carriageReturn: UInt8 = 0x0D
    let lineFeed: UInt8 = 0x0A
    var buffer = Data()
    var sawCarriageReturn = false

    for try await byte in bytes {
      if sawCarriageReturn {
        emitLine(
          from: &buffer,
          parser: &parser,
          state: &state,
          continuation: continuation
        )
        sawCarriageReturn = false

        if byte == lineFeed {
          continue
        }
      }

      switch byte {
      case carriageReturn:
        sawCarriageReturn = true

      case lineFeed:
        emitLine(
          from: &buffer,
          parser: &parser,
          state: &state,
          continuation: continuation
        )

      default:
        buffer.append(byte)
      }
    }

    if sawCarriageReturn || !buffer.isEmpty {
      emitLine(
        from: &buffer,
        parser: &parser,
        state: &state,
        continuation: continuation
      )
    }

    apply(
      result: parser.finish(),
      state: &state,
      continuation: continuation
    )
  }

  private func emitLine(
    from buffer: inout Data,
    parser: inout SSEParser,
    state: inout SSEConnectionState,
    continuation: SSEContinuation
  ) {
    guard let line = String(bytes: buffer, encoding: .utf8) else {
      buffer.removeAll(keepingCapacity: true)
      return
    }
    buffer.removeAll(keepingCapacity: true)

    apply(
      result: parser.process(line: line),
      state: &state,
      continuation: continuation
    )
  }

  private func validateInitialResponse(
    _ response: HTTPResponse,
    rawResponse: HTTPURLResponse
  ) throws {
    guard response.status.isSuccess.rawValue else {
      throw SSEAttemptFailure(
        error: HTTPError.http(
          status: response.status,
          request: response.request,
          response: response
        ),
        openedConnection: false
      )
    }

    guard
      let contentType = rawResponse.value(forHTTPHeaderField: "Content-Type")?
        .lowercased(),
      contentType.hasPrefix("text/event-stream")
    else {
      throw SSEAttemptFailure(
        error: HTTPError(
          category: .custom("SSE", "Expected a text/event-stream response"),
          request: response.request,
          response: response
        ),
        openedConnection: false
      )
    }
  }

  private func apply(
    result: SSEDispatchResult,
    state: inout SSEConnectionState,
    continuation: SSEContinuation
  ) {
    if let retryHint = result.retryHint {
      state.serverRetryHint = retryHint
    }

    guard let event = result.event else {
      return
    }

    if let eventID = event.id, !eventID.isEmpty {
      state.lastEventID = SSELastEventID(eventID.rawValue)
    }

    continuation.yield(.event(event))
  }
}
