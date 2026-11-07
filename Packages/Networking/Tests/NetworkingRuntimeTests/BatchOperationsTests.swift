import Foundation
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

@Suite("Batch Operations Tests")
struct BatchOperationsTests {
  // MARK: - BatchResult Tests

  @Test("BatchResult success properties")
  func batchResultSuccess() {
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.example.com")!)
    let response = HTTPResponse(
      request: request,
      status: .ok,
      headers: [:],
      body: HTTPBody(Data())
    )

    let result = BatchResult(index: 0, request: request, result: .success(response))

    #expect(result.isSuccess.rawValue)
    #expect(result.response != nil)
    #expect(result.error == nil)
    #expect(result.index == 0)
  }

  @Test("BatchResult failure properties")
  func batchResultFailure() {
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.example.com")!)
    let error = HTTPError(category: .timeout)

    let result = BatchResult(index: 1, request: request, result: .failure(error))

    #expect(!result.isSuccess.rawValue)
    #expect(result.response == nil)
    #expect(result.error != nil)
    #expect(result.index == 1)
  }

  // MARK: - BatchConfiguration Tests

  @Test("Default configuration")
  func defaultConfiguration() {
    let config = BatchConfiguration.default
    #expect(config.maxConcurrency == 8)
    #expect(!config.cancelOnFailure.rawValue)
  }

  @Test("Serial configuration")
  func serialConfiguration() {
    let config = BatchConfiguration.serial
    #expect(config.maxConcurrency == 1)
  }

  @Test("Custom configuration")
  func customConfiguration() {
    let config = BatchConfiguration(maxConcurrency: 5, cancelOnFailure: true)
    #expect(config.maxConcurrency == 5)
    #expect(config.cancelOnFailure.rawValue)
  }

  // MARK: - Batch Execution Tests

  @Test("Batch executes multiple requests concurrently")
  func batchExecutesRequests() async throws {
    let mockClient = MockNetworkClient()

    // Setup stubs
    await mockClient.stubGET(path: "/users/1", response: HTTPBody(Data(#"{"id": 1}"#.utf8)))
    await mockClient.stubGET(path: "/users/2", response: HTTPBody(Data(#"{"id": 2}"#.utf8)))
    await mockClient.stubGET(path: "/users/3", response: HTTPBody(Data(#"{"id": 3}"#.utf8)))

    let results = await mockClient.executeBatch([
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/users/1")!),
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/users/2")!),
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/users/3")!),
    ])

    #expect(results.count == 3)
    #expect(results[0].index == 0)
    #expect(results[1].index == 1)
    #expect(results[2].index == 2)
    #expect(results.allSatisfy { $0.isSuccess.rawValue })
  }

  @Test("Batch preserves order of results")
  func batchPreservesOrder() async throws {
    let mockClient = MockNetworkClient()

    await mockClient.stubGET(path: "/a", response: HTTPBody(Data("a".utf8)))
    await mockClient.stubGET(path: "/b", response: HTTPBody(Data("b".utf8)))

    let results = await mockClient.executeBatch([
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/a")!),
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/b")!),
    ])

    #expect(results[0].index == 0)
    #expect(results[1].index == 1)
    #expect(results[0].response?.body == HTTPBody(Data("a".utf8)))
    #expect(results[1].response?.body == HTTPBody(Data("b".utf8)))
  }

  @Test("Batch isolates individual errors")
  func batchIsolatesErrors() async throws {
    let mockClient = MockNetworkClient()

    await mockClient.stubGET(path: "/ok", response: HTTPBody(Data("ok".utf8)))
    await mockClient.expect(
      matching: .method(.get),
      .path("/fail"),
      response: .failure(URLError(.notConnectedToInternet))
    )

    let results = await mockClient.executeBatch([
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/ok")!),
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/fail")!),
    ])

    #expect(results.count == 2)
    #expect(results[0].isSuccess.rawValue)
    #expect(!results[1].isSuccess.rawValue)
    #expect(results[1].error != nil)
  }

  @Test("Batch with empty requests returns empty results")
  func batchEmptyRequests() async {
    let mockClient = MockNetworkClient()
    let results = await mockClient.executeBatch([])
    #expect(results.isEmpty)
  }

  // MARK: - executeBatch Array API

  @Test("executeBatch with array API")
  func executeBatchArray() async throws {
    let mockClient = MockNetworkClient()
    await mockClient.stubGET(path: "/test", response: HTTPBody(Data()))

    let requests = [
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/test")!)
    ]

    let results = await mockClient.executeBatch(requests)
    #expect(results.count == 1)
    #expect(results[0].isSuccess.rawValue)
  }

  // MARK: - Concurrency Limiting Tests

  @Test("executeBatch completes all requests with a concurrency limit")
  func completesBatchWithConcurrencyLimit() async throws {
    let mockClient = MockNetworkClient()

    // Create 20 test requests
    let requests = (1...20).map { index in
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/item/\(index)")!)
    }

    // Stub all requests to return success
    for index in 1...20 {
      await mockClient.stubGET(path: "/item/\(index)", response: HTTPBody(Data()))
    }

    let results = await mockClient.executeBatch(
      requests,
      configuration: BatchConfiguration(maxConcurrency: 5)
    )

    // Verify all requests complete successfully
    #expect(results.count == 20, "Should return all 20 results")
    #expect(results.allSatisfy { $0.isSuccess.rawValue }, "All requests should succeed")

    // Verify order preservation (BATCH-04 requirement)
    for (index, result) in results.enumerated() {
      #expect(result.index.rawValue == index, "Result index should match submission order")
      #expect(
        result.request.url.rawValue.path.contains("/item/\(index + 1)"),
        "Request should match original"
      )
    }
  }

  @Test("Batch stops scheduling requests after a failure when configured")
  func batchStopsSchedulingAfterFailure() async throws {
    let client = BatchFailureClient()
    let requests = try (0..<3).map { index in
      let url = try #require(URL(string: "https://api.example.com/item/\(index)"))
      return HTTPRequest(
        method: .get,
        url: url
      )
    }

    let results = await client.executeBatch(
      requests,
      configuration: BatchConfiguration(maxConcurrency: 1, cancelOnFailure: true)
    )

    #expect(results.count == 1)
    #expect(!results[0].isSuccess.rawValue)
    #expect(await client.requestCount == 1)
  }
}
