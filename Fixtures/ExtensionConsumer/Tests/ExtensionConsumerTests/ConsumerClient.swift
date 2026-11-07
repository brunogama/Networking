import Foundation
import Networking
import Testing

struct ConsumerClient: HTTPClient {
  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    #expect(request.method == .get)
    #expect(request.url.description == "https://example.com/users/42")
    return HTTPResponse(
      request: request,
      status: .ok,
      body: HTTPBody(Data(#"{"name":"Blob"}"#.utf8))
    )
  }
}
