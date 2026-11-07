import NetworkingCore

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
