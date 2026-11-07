import Foundation
import XCTest
@testable import NetworkingRuntime
import NetworkingTesting

actor FileTransferTestMockClient: HTTPClient {
  private(set) var executeCallCount = 0
  private var responseData = Data()

  func setResponseData(_ data: Data) {
    responseData = data
  }

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    executeCallCount += 1

    return HTTPResponse(
      request: request,
      status: .ok,
      headers: [:],
      body: HTTPBody(responseData)
    )
  }

}
