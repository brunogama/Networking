import Foundation
import NetworkingCore
import NetworkingTesting
import Testing

struct MockResponseErrorTests {
  @Test(arguments: [HTTPError.Category.timeout, .cancelled, .http(.unauthorized)])
  func preservesHTTPFailure(category: HTTPError.Category) async throws {
    let original = try request(path: "original")
    let invocation = try request(path: "invocation")
    let response = HTTPResponse(request: original, status: .unauthorized, body: HTTPBody(Data()))
    let expected = HTTPError(
      category: category,
      request: original,
      response: response,
      underlyingError: URLError(.badServerResponse),
      message: "Original failure"
    )
    let client = MockNetworkClient()
    await client.expect(response: .failure(expected), calls: .exactly(1))
    let boundary: any HTTPClient = client

    do {
      _ = try await boundary.execute(invocation)
      Issue.record("Expected the configured HTTP failure")
    } catch let failure as HTTPError {
      #expect(failure.category == expected.category)
      #expect(failure.request?.id == original.id)
      #expect(failure.response?.request.id == response.request.id)
      #expect((failure.underlyingError as? URLError)?.code == .badServerResponse)
      #expect(failure.message == expected.message)
    }
    try await client.verifyExpectations()
  }

  @Test func preservesCancellation() async throws {
    let client = MockNetworkClient()
    await client.expect(response: .failure(CancellationError()), calls: .exactly(1))
    let invocation = try request(path: "cancelled")
    let boundary: any HTTPClient = client

    await #expect(throws: CancellationError.self) { try await boundary.execute(invocation) }
    try await client.verifyExpectations()
  }

  @Test func wrapsExternalFailureWithItsCause() async throws {
    let client = MockNetworkClient()
    await client.expect(response: .failure(URLError(.cannotFindHost)), calls: .exactly(1))
    let invocation = try request(path: "external")
    let boundary: any HTTPClient = client

    do {
      _ = try await boundary.execute(invocation)
      Issue.record("Expected the configured external failure")
    } catch let failure as HTTPError {
      #expect(failure.category == .network(.connectionLost))
      #expect(failure.request?.id == invocation.id)
      #expect((failure.underlyingError as? URLError)?.code == .cannotFindHost)
    }
    try await client.verifyExpectations()
  }

  private func request(path: String) throws -> HTTPRequest {
    HTTPRequest(method: .get, url: try #require(URL(string: "https://mock.test/\(path)")))
  }
}
