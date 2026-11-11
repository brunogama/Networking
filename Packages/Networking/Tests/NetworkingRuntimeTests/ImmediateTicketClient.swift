import Foundation
import NetworkingCore
import NetworkingRuntime
import Testing

struct ImmediateTicketClient: HTTPClient {
  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    HTTPResponse(request: request, status: .ok, body: HTTPBody(Data()))
  }
}
