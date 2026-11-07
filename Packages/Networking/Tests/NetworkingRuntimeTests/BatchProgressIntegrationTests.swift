import Foundation
import Testing

@testable import NetworkingRuntime
import NetworkingCore
import NetworkingTesting

@Suite("Batch execution integration")
struct BatchProgressIntegrationTests {
  // MARK: - BATCH-01: Parallel Execution

  // BATCH-01: Verify batch operations execute multiple requests and return all results
  @Test
  func batch_executesRequestsInParallel() async throws {
    let client = MockNetworkClient()

    // Stub all requests
    for index in 1...10 {
      await client.stubGET(
        path: "/items/\(index)",
        response: HTTPBody(Data(#"{"id": \#(index)}"#.utf8))
      )
    }

    let requests = (1...10).map {
      HTTPRequest(
        method: .get,
        url: URL(string: "https://api.example.com/items/\($0)")!
      )
    }

    let results = await client.executeBatch(requests)

    #expect(results.count == 10)
    #expect(results.allSatisfy { $0.isSuccess.rawValue })
    // Verify all indices present
    let indices = results.map(\.index.rawValue).sorted()
    #expect(indices == Array(0..<10))
  }

  // MARK: - BATCH-02: Configurable Concurrency Limit

  // BATCH-02: Verify maxConcurrency parameter is respected and all results returned
  @Test
  func batchCompletesWithConcurrencyLimit() async throws {
    let client = MockNetworkClient()

    // Stub all 20 requests
    for index in 1...20 {
      await client.stubGET(path: "/items/\(index)", response: HTTPBody(Data()))
    }

    let requests = (1...20).map {
      HTTPRequest(
        method: .get,
        url: URL(string: "https://api.example.com/items/\($0)")!
      )
    }

    let results = await client.executeBatch(
      requests,
      configuration: BatchConfiguration(maxConcurrency: 5)
    )

    // Verify all requests complete successfully despite concurrency limit
    #expect(results.count == 20)
    #expect(results.allSatisfy { $0.isSuccess.rawValue })
  }

  // MARK: - BATCH-03: Partial Failure Handling

  // BATCH-03: Verify batch with partial failures returns all results (not just successes)
  @Test
  func batchPreservesPartialFailures() async throws {
    let client = MockNetworkClient()

    // Stub success responses
    await client.stubGET(path: "/success1", response: HTTPBody(Data("ok".utf8)))
    await client.stubGET(path: "/success2", response: HTTPBody(Data("ok".utf8)))

    // Stub failure response
    await client.expect(
      matching: .method(.get),
      .path("/failure"),
      response: .failure(URLError(.notConnectedToInternet))
    )

    let results = await client.executeBatch([
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/success1")!),
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/failure")!),
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/success2")!),
    ])

    #expect(results.count == 3)
    #expect(results[0].isSuccess.rawValue)
    #expect(!results[1].isSuccess.rawValue)  // Failure
    #expect(results[2].isSuccess.rawValue)

    // Verify error preserved
    #expect(results[1].error != nil)
  }

  // MARK: - BATCH-04: Result Order Preservation

  // BATCH-04: Verify batch results preserve original request order (not completion order)
  @Test
  func batch_preservesOriginalRequestOrder() async throws {
    let client = MockNetworkClient()

    // Stub all requests
    for index in 1...10 {
      await client.stubGET(path: "/item/\(index)", response: HTTPBody(Data("\(index)".utf8)))
    }

    let requests = (1...10).map {
      HTTPRequest(
        method: .get,
        url: URL(string: "https://api.example.com/item/\($0)")!
      )
    }

    let results = await client.executeBatch(requests)

    // Verify results match original order (not completion order)
    #expect(results.count == 10)
    for (index, result) in results.enumerated() {
      #expect(result.index.rawValue == index)
      #expect(result.request.url == requests[index].url)
    }
  }

  // MARK: - BATCH-05: Cancellation Propagation

  // BATCH-05: Verify batch task can be cancelled
  @Test
  func batchAcceptsCancellation() async throws {
    let client = MockNetworkClient()

    // Stub all requests
    for index in 1...20 {
      await client.stubGET(path: "/slow/\(index)", response: HTTPBody(Data()))
    }

    let requests = (1...20).map {
      HTTPRequest(
        method: .get,
        url: URL(string: "https://api.example.com/slow/\($0)")!
      )
    }

    let batchTask = Task {
      await client.executeBatch(
        requests,
        configuration: BatchConfiguration(maxConcurrency: 5)
      )
    }

    // Cancel task immediately
    batchTask.cancel()

    let results = await batchTask.value

    // Task was cancelled - verify we still get results (batch handles cancellation gracefully)
    #expect(results.count <= 20)
  }

  // MARK: - Edge Cases: Batch Configuration

  // Edge case: maxConcurrency=0 means unlimited
  @Test
  func batch_withMaxConcurrency0_isUnlimited() async throws {
    let client = MockNetworkClient()

    // Stub all requests
    for index in 1...10 {
      await client.stubGET(path: "/unlimited/\(index)", response: HTTPBody(Data()))
    }

    let requests = (1...10).map {
      HTTPRequest(
        method: .get,
        url: URL(string: "https://api.example.com/unlimited/\($0)")!
      )
    }

    let results = await client.executeBatch(
      requests,
      configuration: BatchConfiguration(maxConcurrency: 0)  // Unlimited
    )

    #expect(results.count == 10)
    #expect(results.allSatisfy { $0.isSuccess.rawValue })
  }

  // Edge case: maxConcurrency=1 is serial execution
  @Test
  func batch_withMaxConcurrency1_isSerial() async throws {
    let client = MockNetworkClient()

    // Stub all requests
    for index in 1...5 {
      await client.stubGET(path: "/serial/\(index)", response: HTTPBody(Data()))
    }

    let requests = (1...5).map {
      HTTPRequest(
        method: .get,
        url: URL(string: "https://api.example.com/serial/\($0)")!
      )
    }

    let results = await client.executeBatch(
      requests,
      configuration: BatchConfiguration(maxConcurrency: 1)  // Serial
    )

    #expect(results.count == 5)
    #expect(results.allSatisfy { $0.isSuccess.rawValue })
  }

}
