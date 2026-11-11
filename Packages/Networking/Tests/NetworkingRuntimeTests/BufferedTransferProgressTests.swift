import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

@Suite("Buffered transfer progress")
struct BufferedTransferProgressTests {
  @Test func uploadReportsActualCompletedBytes() async throws {
    let client = MockNetworkClient()
    await client.expect()
    let transfers = FileTransferOperations(httpClient: client)
    let payload = HTTPBody(Data("Hello, World!".utf8))
    let events = AsyncStream<TransferProgress>.makeStream()
    let result = try await transfers.uploadData(
      payload,
      fileName: "test.txt",
      to: RemoteTransferURL(try #require(URL(string: "https://example.test/upload"))),
      mimeType: "text/plain"
    ) { events.continuation.yield($0) }
    events.continuation.finish()
    var updates: [TransferProgress] = []
    for await update in events.stream { updates.append(update) }
    #expect(result.isSuccessful == true)
    #expect(result.bytesTransferred == TransferByteCount(Int64(payload.count.rawValue)))
    #expect(updates.last?.phase == .completed)
    #expect(updates.last?.transferredBytes == result.bytesTransferred)
  }

  @Test func downloadReturnsTheReceivedBody() async throws {
    let payload = HTTPBody(Data("Downloaded content".utf8))
    let client = MockNetworkClient()
    await client.expect(response: .success(statusCode: 200, data: payload))
    let transfers = FileTransferOperations(httpClient: client)
    let download = try await transfers.downloadData(
      from: RemoteTransferURL(try #require(URL(string: "https://example.test/download")))
    )
    #expect(download.data == payload)
    #expect(download.result.isSuccessful == true)
  }
}
