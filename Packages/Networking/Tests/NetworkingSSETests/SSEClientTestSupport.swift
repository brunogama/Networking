import Foundation
import NetworkingCore

@testable import NetworkingSSE

struct AuthorizationMiddleware: HTTPRequestMiddleware {
  let token: String

  func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    var headers = request.headers
    headers["Authorization"] = "Bearer \(token)"
    return HTTPRequest(
      method: request.method,
      url: request.url,
      headers: headers,
      body: request.body,
      timeout: request.timeout
    )
  }
}

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
