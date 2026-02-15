import Testing
import Foundation
@testable import Networking

@Suite("Batch Operations Tests")
struct BatchOperationsTests {

  // MARK: - BatchResult Tests

  @Test("BatchResult success properties")
  func testBatchResultSuccess() {
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.example.com")!)
    let response = HTTPResponse(
      request: request,
      status: .ok,
      headers: [:],
      body: Data()
    )

    let result = BatchResult(index: 0, request: request, result: .success(response))

    #expect(result.isSuccess)
    #expect(result.response != nil)
    #expect(result.error == nil)
    #expect(result.index == 0)
  }

  @Test("BatchResult failure properties")
  func testBatchResultFailure() {
    let request = HTTPRequest(method: .get, url: URL(string: "https://api.example.com")!)
    let error = HTTPError(category: .timeout)

    let result = BatchResult(index: 1, request: request, result: .failure(error))

    #expect(!result.isSuccess)
    #expect(result.response == nil)
    #expect(result.error != nil)
    #expect(result.index == 1)
  }

  // MARK: - BatchConfiguration Tests

  @Test("Default configuration")
  func testDefaultConfiguration() {
    let config = BatchConfiguration.default
    #expect(config.maxConcurrency == 0)
    #expect(!config.cancelOnFailure)
  }

  @Test("Serial configuration")
  func testSerialConfiguration() {
    let config = BatchConfiguration.serial
    #expect(config.maxConcurrency == 1)
  }

  @Test("Custom configuration")
  func testCustomConfiguration() {
    let config = BatchConfiguration(maxConcurrency: 5, cancelOnFailure: true)
    #expect(config.maxConcurrency == 5)
    #expect(config.cancelOnFailure)
  }

  // MARK: - Batch Execution Tests

  @Test("Batch executes multiple requests concurrently")
  func testBatchExecutesRequests() async throws {
    let mockClient = MockNetworkClient()

    // Setup stubs
    mockClient.stubGET(path: "/users/1", response: #"{"id": 1}"#.data(using: .utf8)!)
    mockClient.stubGET(path: "/users/2", response: #"{"id": 2}"#.data(using: .utf8)!)
    mockClient.stubGET(path: "/users/3", response: #"{"id": 3}"#.data(using: .utf8)!)

    let results = await mockClient.batch {
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/users/1")!)
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/users/2")!)
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/users/3")!)
    }

    #expect(results.count == 3)
    #expect(results[0].index == 0)
    #expect(results[1].index == 1)
    #expect(results[2].index == 2)
    #expect(results.allSatisfy { $0.isSuccess })
  }

  @Test("Batch preserves order of results")
  func testBatchPreservesOrder() async throws {
    let mockClient = MockNetworkClient()

    mockClient.stubGET(path: "/a", response: "a".data(using: .utf8)!)
    mockClient.stubGET(path: "/b", response: "b".data(using: .utf8)!)

    let results = await mockClient.batch {
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/a")!)
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/b")!)
    }

    #expect(results[0].index == 0)
    #expect(results[1].index == 1)
    #expect(results[0].response?.body == "a".data(using: .utf8))
    #expect(results[1].response?.body == "b".data(using: .utf8))
  }

  @Test("Batch isolates individual errors")
  func testBatchIsolatesErrors() async throws {
    let mockClient = MockNetworkClient()

    mockClient.stubGET(path: "/ok", response: "ok".data(using: .utf8)!)
    mockClient.expectGET("/fail")
      .andReturnError(URLError(.notConnectedToInternet))

    let results = await mockClient.batch {
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/ok")!)
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/fail")!)
    }

    #expect(results.count == 2)
    #expect(results[0].isSuccess)
    #expect(!results[1].isSuccess)
    #expect(results[1].error != nil)
  }

  @Test("Batch with empty requests returns empty results")
  func testBatchEmptyRequests() async {
    let mockClient = MockNetworkClient()
    let results = await mockClient.executeBatch([])
    #expect(results.isEmpty)
  }

  // MARK: - executeBatch Array API

  @Test("executeBatch with array API")
  func testExecuteBatchArray() async throws {
    let mockClient = MockNetworkClient()
    mockClient.stubGET(path: "/test", response: Data())

    let requests = [
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/test")!)
    ]

    let results = await mockClient.executeBatch(requests)
    #expect(results.count == 1)
    #expect(results[0].isSuccess)
  }
}
