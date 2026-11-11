#if os(macOS)
import Foundation
import NetworkingCore
import Testing

@testable import NetworkingRuntime

struct DownloadLimitRegressionTests {
  @Test(arguments: [true, false])
  func oversizedDownloadCannotReplaceDestination(native: Bool) async throws {
    let server = try HTTPDiagnosticsServer()
    defer { server.stop() }
    let transport = NetworkClient()
    let client: any HTTPClient = native ? transport : BufferedDownloadClient(client: transport)
    let operations = FileTransferOperations(
      httpClient: client,
      configuration: .init(maxFileSize: 4)
    )
    let destination = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString
    )
    let original = Data("existing".utf8)
    try original.write(to: destination)
    defer { try? FileManager.default.removeItem(at: destination) }
    await #expect(throws: FileTransferError.self) {
      try await operations.downloadFile(
        from: RemoteTransferURL(server.baseURL),
        to: LocalFileURL(destination)
      )
    }
    #expect(try Data(contentsOf: destination) == original)
    await #expect(throws: FileTransferError.self) {
      try await operations.downloadData(from: RemoteTransferURL(server.baseURL))
    }
  }

  @Test func nativeDownloadHonorsClientResponseLimit() async throws {
    let server = try HTTPDiagnosticsServer()
    defer { server.stop() }
    let client = NetworkClient(maximumResponseBytes: 4)
    let request = HTTPRequest(method: .get, url: server.baseURL)
    do {
      let result = try await client.download(request, progress: nil)
      try FileManager.default.removeItem(at: result.temporaryFileURL)
      Issue.record("Expected native download size rejection")
    } catch let error as HTTPError {
      guard case .configuration = error.category else {
        Issue.record("Expected size-limit failure, received \(error.category)")
        return
      }
    }
  }

  @Test(arguments: [true, false])
  func exactSizeDownloadSucceeds(native: Bool) async throws {
    let server = try HTTPDiagnosticsServer()
    defer { server.stop() }
    let transport = NetworkClient(maximumResponseBytes: 7)
    let client: any HTTPClient = native ? transport : BufferedDownloadClient(client: transport)
    let operations = FileTransferOperations(
      httpClient: client,
      configuration: .init(maxFileSize: 7)
    )
    let destination = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString
    )
    defer { try? FileManager.default.removeItem(at: destination) }
    let result = try await operations.downloadFile(
      from: RemoteTransferURL(server.baseURL),
      to: LocalFileURL(destination)
    )
    #expect(result.bytesTransferred == 7)
    #expect(try Data(contentsOf: destination) == Data("payload".utf8))
    let downloaded = try await operations.downloadData(from: RemoteTransferURL(server.baseURL))
    #expect(downloaded.data == HTTPBody(Data("payload".utf8)))
  }
}
#endif
