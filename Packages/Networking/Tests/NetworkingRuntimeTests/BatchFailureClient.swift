import NetworkingCore

actor BatchFailureClient: HTTPClient {
  private(set) var requestCount = 0

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    requestCount += 1
    if request.url.rawValue.path == "/item/0" {
      throw HTTPError.network(.serverUnreachable, request: request)
    }

    return HTTPResponse(request: request, status: .ok, headers: HTTPHeaders())
  }
}
