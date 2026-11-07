import Foundation
import NetworkingCore
import NetworkingRuntime
import Testing

actor RetryTestTransport: HTTPClient {
  private var failures: [HTTPError.Category]
  private(set) var requests: [HTTPRequest] = []

  init(failures: [HTTPError.Category]) {
    self.failures = failures
  }

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    requests.append(request)
    guard failures.isEmpty else {
      throw HTTPError(category: failures.removeFirst(), request: request)
    }
    return HTTPResponse(request: request, status: .ok, body: HTTPBody?.none)
  }
}
