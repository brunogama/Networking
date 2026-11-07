import Foundation
import NetworkingCore
@testable import NetworkingRuntime
@testable import NetworkingTesting
import Testing

struct CachingTestMockHTTPClient: HTTPClient {
  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    // Return a basic response for testing
    HTTPResponse(
      request: request,
      status: .ok,
      headers: [:],
      body: HTTPBody(Data("mock response".utf8))
    )
  }
}
