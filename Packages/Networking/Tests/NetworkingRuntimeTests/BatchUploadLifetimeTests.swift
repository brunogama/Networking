import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import Testing
import os

@Suite("Batch upload lifetime")
struct BatchUploadLifetimeTests {
  @Test func uploadsOverlapAndReturnInputOrder() async throws {
    let directory = try makeFiles()
    defer { try? FileManager.default.removeItem(at: directory) }
    let client = BatchUploadProbe()
    let transfers = FileTransferOperations(httpClient: client)
    let results = try await transfers.uploadFiles(
      from: sourceFiles(directory),
      to: destinations()
    )
    #expect(await client.maximumActive == 2)
    #expect(await client.active == 0)
    #expect(results.map { $0.fileMetadata?.name.rawValue } == ["first.txt", "second.txt"])
  }

  @Test func cancellationJoinsActiveUploads() async throws {
    let directory = try makeFiles()
    defer { try? FileManager.default.removeItem(at: directory) }
    let client = BatchUploadProbe(releaseAutomatically: false)
    let transfers = FileTransferOperations(httpClient: client)
    let destinations = try destinations()
    let operation = Task {
      try await transfers.uploadFiles(from: sourceFiles(directory), to: destinations)
    }
    await client.waitForStarts(1)
    operation.cancel()
    await #expect(throws: CancellationError.self) { try await operation.value }
    #expect(await client.active == 0)
  }

  @Test func progressIsDeliveredBeforeReturning() async throws {
    let directory = try makeFiles()
    defer { try? FileManager.default.removeItem(at: directory) }
    let client = BatchUploadProbe()
    let transfers = FileTransferOperations(httpClient: client)
    let updates = OSAllocatedUnfairLock(initialState: [TransferProgress]())
    let results = try await transfers.uploadFiles(
      from: sourceFiles(directory),
      to: destinations()
    ) { update in
      updates.withLock { $0.append(update) }
    }
    let delivered = updates.withLock { $0 }
    #expect(delivered.count == results.count)
    #expect(delivered.allSatisfy { $0.phase == .completed })
    #expect(delivered.allSatisfy { $0.transferredBytes == 7 })
  }

  @Test func concurrencyLimitIsRespected() async throws {
    let directory = try makeFiles()
    defer { try? FileManager.default.removeItem(at: directory) }
    let client = BatchUploadProbe()
    let transfers = FileTransferOperations(httpClient: client)
    let results = try await transfers.uploadFiles(
      from: sourceFiles(directory),
      to: destinations(),
      maxConcurrency: 1
    )
    #expect(results.count == 2)
    #expect(await client.maximumActive == 1)
    #expect(await client.active == 0)
  }

  @Test(arguments: [0, -1])
  func nonpositiveConcurrencyIsRejected(limit: Int) async {
    let transfers = FileTransferOperations(httpClient: BatchUploadProbe())
    await #expect(throws: HTTPError.self) {
      try await transfers.uploadFiles(
        from: [],
        to: [],
        maxConcurrency: BatchConcurrencyLimit(limit)
      )
    }
  }

  private func makeFiles() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for file in sourceFiles(directory) { try Data("payload".utf8).write(to: file.rawValue) }
    return directory
  }

  private func sourceFiles(_ directory: URL) -> [LocalFileURL] {
    ["first.txt", "second.txt"].map { LocalFileURL(directory.appendingPathComponent($0)) }
  }

  private func destinations() throws -> [RemoteTransferURL] {
    let endpoint = try #require(URL(string: "https://example.test/upload"))
    return [RemoteTransferURL(endpoint), RemoteTransferURL(endpoint)]
  }
}
