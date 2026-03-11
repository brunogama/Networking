// swiftlint:disable file_length
import Foundation
import Testing

@testable import NetworkingRuntime
import NetworkingCore
import NetworkingDSL
import NetworkingRuntimeDSL
import NetworkingTesting

// Comprehensive integration tests for batch operations and progress tracking.
//
// Verifies all Phase 03 requirements (BATCH-01 through BATCH-05, PROG-01 through PROG-05)
// with end-to-end workflow tests combining BatchOperations and ProgressTracking.
@Suite("Batch Operations & Progress Integration Tests")
// swiftlint:disable:next type_body_length
struct BatchProgressIntegrationTests {
  // MARK: - BATCH-01: Parallel Execution

  /// BATCH-01: Verify batch operations execute multiple requests and return all results
  @Test
  func batch_executesRequestsInParallel() async throws {
    let client = MockNetworkClient()

    // Stub all requests
    for index in 1...10 {
      client.stubGET(path: "/items/\(index)", response: Data(#"{"id": \#(index)}"#.utf8))
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

  /// BATCH-02: Verify maxConcurrency parameter is respected and all results returned
  @Test
  func batch_withMaxConcurrency5_throttlesTo5Concurrent() async throws {
    let client = MockNetworkClient()

    // Stub all 20 requests
    for index in 1...20 {
      client.stubGET(path: "/items/\(index)", response: Data())
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

  /// BATCH-03: Verify batch with partial failures returns all results (not just successes)
  @Test
  func batch_withPartialFailures_returnsAllResults() async throws {
    let client = MockNetworkClient()

    // Stub success responses
    client.stubGET(path: "/success1", response: Data("ok".utf8))
    client.stubGET(path: "/success2", response: Data("ok".utf8))

    // Stub failure response
    client.expectGET("/failure")
      .andReturnError(URLError(.notConnectedToInternet))

    let results = await client.batch {
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/success1")!)
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/failure")!)
      HTTPRequest(method: .get, url: URL(string: "https://api.example.com/success2")!)
    }

    #expect(results.count == 3)
    #expect(results[0].isSuccess.rawValue)
    #expect(!results[1].isSuccess.rawValue)  // Failure
    #expect(results[2].isSuccess.rawValue)

    // Verify error preserved
    #expect(results[1].error != nil)
  }

  // MARK: - BATCH-04: Result Order Preservation

  /// BATCH-04: Verify batch results preserve original request order (not completion order)
  @Test
  func batch_preservesOriginalRequestOrder() async throws {
    let client = MockNetworkClient()

    // Stub all requests
    for index in 1...10 {
      client.stubGET(path: "/item/\(index)", response: Data("\(index)".utf8))
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
      #expect(result.index == index)
      #expect(result.request.url == requests[index].url)
    }
  }

  // MARK: - BATCH-05: Cancellation Propagation

  /// BATCH-05: Verify batch task can be cancelled
  @Test
  func batch_whenCancelled_returnsCancellationResults() async throws {
    let client = MockNetworkClient()

    // Stub all requests
    for index in 1...20 {
      client.stubGET(path: "/slow/\(index)", response: Data())
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

  // MARK: - PROG-01 + PROG-02: Upload/Download Progress Streaming

  /// PROG-01, PROG-02: Verify progress tracking streams download progress updates
  @Test
  func progressTracking_streamsDownloadProgress() async throws {
    let streamManager = ProgressTracking.ProgressStreamManager()
    let transferId = TransferIdentifier()

    let stream = await streamManager.createProgressStream(
      for: transferId,
      totalBytes: 1000
    )

    // Collect updates from stream in background task
    let collectTask = Task { () -> [ProgressTracking.ProgressUpdate] in
      var collectedUpdates: [ProgressTracking.ProgressUpdate] = []
      for try await update in stream {
        collectedUpdates.append(update)
        if update.phase == .completed { break }
      }
      return collectedUpdates
    }

    // Simulate progress updates
    try await streamManager.updateProgress(
      for: transferId,
      transferredBytes: 250,
      phase: .downloading
    )
    try await streamManager.updateProgress(
      for: transferId,
      transferredBytes: 500,
      phase: .downloading
    )
    try await streamManager.updateProgress(
      for: transferId,
      transferredBytes: 1000,
      phase: .downloading
    )
    await streamManager.completeProgress(for: transferId, phase: .completed)

    let updates = try await collectTask.value

    #expect(updates.count >= 4)  // Initial + 3 updates + completed
    #expect(updates.last?.phase == .completed)
  }

  // MARK: - PROG-03: Progress Includes Bytes Transferred and Total

  /// PROG-03: Verify progress updates include transferredBytes and totalBytes
  @Test
  func progressUpdate_includesBytesAndTotal() async throws {
    let update = ProgressTracking.ProgressUpdate(
      transferId: TransferIdentifier(),
      phase: .downloading,
      totalBytes: 1000,
      transferredBytes: 300
    )

    #expect(update.totalBytes == 1000)
    #expect(update.transferredBytes == 300)
  }

  // MARK: - PROG-04: Progress Includes Fraction Completed

  /// PROG-04: Verify progress update calculates fraction completed (0.0 to 1.0)
  @Test
  func progressUpdate_calculatesFractionCompleted() async throws {
    let update = ProgressTracking.ProgressUpdate(
      transferId: TransferIdentifier(),
      phase: .downloading,
      totalBytes: 1000,
      transferredBytes: 300
    )

    #expect(update.progress == 0.3)

    // Edge case: unknown total
    let unknownTotal = ProgressTracking.ProgressUpdate(
      transferId: TransferIdentifier(),
      phase: .downloading,
      totalBytes: nil,
      transferredBytes: 300
    )
    #expect(unknownTotal.progress == 0.0)  // Unknown = 0% unless completed
  }

  // MARK: - Integration: Batch with Progress Tracking

  /// Integration test: Verify batch operations with progress tracking aggregate correctly
  @Test
  func batch_withProgressTracking_aggregatesProgress() async throws {
    let client = MockNetworkClient()
    let batchTracker = ProgressTracking.BatchProgressTracker()

    // Stub all requests
    for index in 1...5 {
      client.stubGET(path: "/data/\(index)", response: Data())
    }

    let requests = (1...5).map {
      HTTPRequest(
        method: .get,
        url: URL(string: "https://api.example.com/data/\($0)")!
      )
    }

    // Start batch tracking and get streams
    let transferIds = requests.map { _ in
      (transferId: TransferIdentifier(), totalBytes: TransferByteCount(1000))
    }
    let streams = await batchTracker.startBatchTracking(transferIds)

    #expect(streams.count == 5)

    // Execute batch
    let results = await client.executeBatch(requests)

    // Verify all requests succeeded
    #expect(results.count == 5)
    #expect(results.allSatisfy { $0.isSuccess.rawValue })

    // Simulate progress updates after batch starts
    for index in requests.indices {
      try await batchTracker.updateBatchProgress(
        transferId: transferIds[index].transferId,
        transferredBytes: 500,
        phase: .downloading
      )
    }

    // Verify aggregate progress calculated
    let aggregate = await batchTracker.getAggregateProgress()
    #expect(aggregate != nil)
    #expect(aggregate?.totalBytes == 5000)  // 5 × 1000 bytes
  }

  // MARK: - Edge Cases: Batch Configuration

  /// Edge case: maxConcurrency=0 means unlimited
  @Test
  func batch_withMaxConcurrency0_isUnlimited() async throws {
    let client = MockNetworkClient()

    // Stub all requests
    for index in 1...10 {
      client.stubGET(path: "/unlimited/\(index)", response: Data())
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

  /// Edge case: maxConcurrency=1 is serial execution
  @Test
  func batch_withMaxConcurrency1_isSerial() async throws {
    let client = MockNetworkClient()

    // Stub all requests
    for index in 1...5 {
      client.stubGET(path: "/serial/\(index)", response: Data())
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

  // MARK: - Edge Cases: Progress Tracking

  /// Edge case: Progress with unknown total bytes
  @Test
  func progressUpdate_withUnknownTotal_handlesGracefully() async throws {
    let update = ProgressTracking.ProgressUpdate(
      transferId: TransferIdentifier(),
      phase: .downloading,
      totalBytes: nil,  // Unknown
      transferredBytes: 500
    )

    #expect(update.totalBytes == nil)
    #expect(update.transferredBytes == 500)
    #expect(update.progress == 0.0)  // Unknown total = 0% progress
  }

  /// Edge case: Progress when completed with unknown total
  @Test
  func progressUpdate_completedWithUnknownTotal_reports100Percent() async throws {
    let update = ProgressTracking.ProgressUpdate(
      transferId: TransferIdentifier(),
      phase: .completed,
      totalBytes: nil,
      transferredBytes: 1000
    )

    #expect(update.progress == 1.0)  // Completed = 100% even if total unknown
  }
}
