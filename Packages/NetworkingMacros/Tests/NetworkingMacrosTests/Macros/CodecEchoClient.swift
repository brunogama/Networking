import Foundation
import Networking
import NetworkingMacros
import Testing

actor CodecEchoClient: HTTPClient {
  private(set) var requests: [HTTPRequest] = []

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    requests.append(request)
    let fallback = Data(#"{"display_name":"Blob","created_at":0}"#.utf8)
    return HTTPResponse(request: request, status: .ok, body: request.body ?? HTTPBody(fallback))
  }
}
