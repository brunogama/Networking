import Foundation
import NetworkingCore

@testable import NetworkingSSE

func makeClient() -> SSEClient {
  SSEClient(session: makeSession())
}

func makeRequest(
  url: URL,
  method: HTTPMethod = .get,
  headers: [String: String] = [:]
) -> HTTPRequest {
  HTTPRequest(method: method, url: url, headers: headers)
}

func makeSession() -> URLSession {
  URLSession(configuration: .ephemeral)
}

func makeServer(
  path: String,
  scripts: [SSETestResponseScript]
) async throws -> (server: SSETestServer, url: URL) {
  let server = try SSETestServer(scripts: scripts)
  try await server.start()
  return (server, try server.makeURL(path: path))
}
