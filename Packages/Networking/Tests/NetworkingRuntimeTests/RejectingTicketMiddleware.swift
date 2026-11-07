import Foundation
import NetworkingCore
import NetworkingRuntime
import Testing

struct RejectingTicketMiddleware: HTTPRequestMiddleware {
  func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    throw TicketTestFailure()
  }
}
