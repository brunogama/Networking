import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

struct PausedCacheClient: HTTPClient {
  let pause: CachePause

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    await pause.suspend()
    let cookie = request.headers.caseInsensitiveValue(for: "Cookie")?.rawValue ?? "anonymous"
    return HTTPResponse(
      request: request,
      status: .ok,
      headers: ["Vary": "Cookie"],
      body: HTTPBody(Data(cookie.utf8))
    )
  }
}
