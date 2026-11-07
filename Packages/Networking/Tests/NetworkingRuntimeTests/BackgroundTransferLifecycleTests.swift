#if os(macOS)
import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import Testing

@Suite("Background transfer lifecycle")
struct BackgroundTransferLifecycleTests {
  @Test func coordinatorReturnsClaimedDownload() async throws {
    let server = try HTTPDiagnosticsServer()
    defer { server.stop() }
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("claimed.bin")
    let payload = Data("claimed download".utf8)
    try payload.write(to: file)
    let coordinator = BackgroundTransferCoordinator(configuration: .default)
    let task = session.downloadTask(with: server.baseURL.appendingPathComponent("wait"))
    let transferId = TransferIdentifier()
    async let pending = coordinator.resume(
      task: task,
      transferId: transferId,
      progressCallback: nil
    )
    let event = try await server.nextEvent()
    #expect(event == "started")
    await coordinator.didComplete(task: task, completion: .success(file))
    let result = try await pending
    #expect(result.transferId == transferId)
    #expect(result.fileURL == LocalFileURL(file))
    #expect(result.bytesTransferred == TransferByteCount(Int64(payload.count)))
    #expect(try Data(contentsOf: file) == payload)
  }
}
#endif
