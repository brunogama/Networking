import Foundation
import NetworkingCore
import NetworkingRuntime

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct SSEOpenedConnection: ~Copyable {
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
    let prepared = try await applyRequestMiddlewares(request)
    let exchange = HTTPExchange<ExchangePrepared>(diagnostics: diagnostics).start(prepared)
    do {
      let connection = try await openConnection(
        for: prepared,
        configuration: configuration,
        state: state,
        traceID: exchange.id
      )
      defer { connection.bytes.task.cancel() }
      try yieldEvent(.open, to: continuation)
      try await streamEvents(
        from: connection,
        maximumResponseBytes: configuration.maximumResponseBytes,
        state: &state,
        continuation: continuation
      )
      exchange.finish(connection.response)
    } catch {
      exchange.fail(error)
      throw error
    }
  }

  private func openConnection(
    for request: HTTPRequest,
    configuration: SSEConfiguration,
    state: borrowing SSEConnectionState,
    traceID: HTTPTraceID?
  ) async throws -> SSEOpenedConnection {
    let urlRequest = try buildURLRequest(
      from: request,
      configuration: configuration,
      state: state
    )
    let (bytes, response) = try await fetchResponse(
      for: urlRequest,
      request: request,
      traceID: traceID
    )
    let connection = try makeOpenedConnection(
      bytes: bytes,
      response: response,
      request: request
    )

    do {
      try validateInitialResponse(connection.response, rawResponse: connection.rawResponse)
    } catch {
      connection.bytes.task.cancel()
      throw error
    }
    return connection
  }

  private func fetchResponse(
    for urlRequest: URLRequest,
    request: HTTPRequest,
    traceID: HTTPTraceID?
  ) async throws -> (URLSession.AsyncBytes, URLResponse) {
    do {
      return try await session.bytes(
        for: urlRequest,
        delegate: HTTPTaskDelegate(diagnostics: diagnostics, traceID: traceID)
      )
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

    let metadata = responseMetadata(for: request, from: rawResponse)

    return SSEOpenedConnection(
      request: request,
      response: metadata,
      rawResponse: rawResponse,
      bytes: bytes
    )
  }

  private func streamEvents(
    from connection: borrowing SSEOpenedConnection,
    maximumResponseBytes: Int?,
    state: inout SSEConnectionState,
    continuation: SSEContinuation
  ) async throws {
    do {
      try await streamBytes(
        from: connection.bytes,
        maximumResponseBytes: maximumResponseBytes,
        state: &state,
        continuation: continuation
      )
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as SSEStreamError {
      throw error
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


}

private func responseMetadata(
  for request: HTTPRequest,
  from response: HTTPURLResponse
) -> HTTPResponse {
  let headers: [String: String] = Dictionary(
    uniqueKeysWithValues: response.allHeaderFields.compactMap { key, value in
      guard let name = key as? String, let headerValue = value as? String else { return nil }
      return (name, headerValue)
    }
  )
  return HTTPResponse(
    request: request,
    status: HTTPStatus(rawValue: HTTPStatusCode(response.statusCode)),
    headers: HTTPHeaders(rawValue: headers),
    url: response.url.map { HTTPResponseURL(rawValue: $0) }
  )
}
