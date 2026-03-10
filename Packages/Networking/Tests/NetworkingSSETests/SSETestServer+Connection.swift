import Foundation
import Network

extension SSETestServer {
  func serve(_ connection: NWConnection) async {
    defer { connection.cancel() }

    do {
      let requestData = try await receiveRequest(from: connection)
      let request = try parseRequest(from: requestData)
      await state.record(request)

      guard let script = await state.nextScript() else {
        return
      }

      try await sendResponse(script, on: connection)
    } catch {
      return
    }
  }

  func receiveRequest(from connection: NWConnection) async throws -> Data {
    let delimiter = Data("\r\n\r\n".utf8)
    var requestData = Data()

    while !contains(delimiter, in: requestData) {
      let chunk = try await receiveChunk(from: connection)
      guard !chunk.isEmpty else {
        throw SSETestServerError.connectionClosed
      }

      requestData.append(chunk)
    }

    return requestData
  }

  func receiveChunk(from connection: NWConnection) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      connection.receive(
        minimumIncompleteLength: 1,
        maximumLength: 4096
      ) { content, _, isComplete, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }

        if let content, !content.isEmpty {
          continuation.resume(returning: content)
          return
        }

        if isComplete {
          continuation.resume(returning: Data())
          return
        }

        continuation.resume(throwing: SSETestServerError.connectionClosed)
      }
    }
  }

  func parseRequest(from data: Data) throws -> SSECapturedRequest {
    guard let text = String(data: data, encoding: .utf8) else {
      throw SSETestServerError.invalidRequest
    }

    let headerBlock = text.components(separatedBy: "\r\n\r\n").first ?? text
    let lines = headerBlock.components(separatedBy: "\r\n")
    guard let requestLine = lines.first else {
      throw SSETestServerError.invalidRequest
    }

    let components = requestLine.split(separator: " ", maxSplits: 2)
    guard components.count >= 2 else {
      throw SSETestServerError.invalidRequest
    }

    let headers = parseHeaders(from: lines)
    return SSECapturedRequest(
      method: String(components[0]),
      path: String(components[1]),
      headers: headers
    )
  }

  func sendResponse(
    _ script: SSETestResponseScript,
    on connection: NWConnection
  ) async throws {
    try await send(makeResponseHead(for: script), on: connection)

    for chunk in script.chunks {
      if chunk.delay > 0 {
        try await Task.sleep(for: .seconds(chunk.delay))
      }

      try await send(chunk.data, on: connection)
    }
  }

  func makeResponseHead(for script: SSETestResponseScript) -> Data {
    let statusLine =
      "HTTP/1.1 \(script.statusCode) "
      + HTTPURLResponse.localizedString(forStatusCode: script.statusCode).capitalized
    let headers = script.headers.map { "\($0.key): \($0.value)" }
    let response = ([statusLine] + headers + ["Connection: close", "", ""]).joined(
      separator: "\r\n"
    )
    return Data(response.utf8)
  }

  func send(
    _ data: Data,
    on connection: NWConnection
  ) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      connection.send(
        content: data,
        completion: .contentProcessed { error in
          if let error {
            continuation.resume(throwing: error)
            return
          }

          continuation.resume()
        }
      )
    }
  }

  func contains(
    _ delimiter: Data,
    in data: Data
  ) -> Bool {
    // swiftlint:disable:next contains_over_range_nil_comparison
    data.range(of: delimiter) != nil
  }

  func parseHeaders(from lines: [String]) -> [String: String] {
    lines.dropFirst().reduce(into: [String: String]()) { headers, line in
      let pieces = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
      guard pieces.count == 2 else {
        return
      }

      let key = String(pieces[0]).trimmingCharacters(in: .whitespaces)
      let value = String(pieces[1]).trimmingCharacters(in: .whitespaces)
      headers[key] = value
    }
  }
}
