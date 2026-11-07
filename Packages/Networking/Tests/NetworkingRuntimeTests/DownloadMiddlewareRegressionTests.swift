#if os(macOS)
import Foundation
import NetworkingCore
import NetworkingRuntime
import NetworkingTesting
import Testing

extension DownloadLimitRegressionTests {
  @Test(arguments: [true, false])
  func downloadsPreserveResponseTransformations(toFile: Bool) async throws {
    let server = try HTTPDiagnosticsServer()
    defer { server.stop() }
    let middleware = MockHTTPResponseMiddleware()
    let transformed = HTTPBody(Data("transformed".utf8))
    await middleware.stubReplaceBody(transformed)
    let client = NetworkClient(responseMiddlewares: [middleware])
    let operations = FileTransferOperations(httpClient: client)
    let destination = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString
    )
    defer { try? FileManager.default.removeItem(at: destination) }
    if toFile {
      _ = try await operations.downloadFile(
        from: RemoteTransferURL(server.baseURL),
        to: LocalFileURL(destination)
      )
      #expect(try Data(contentsOf: destination) == transformed.rawValue)
    } else {
      let result = try await operations.downloadData(from: RemoteTransferURL(server.baseURL))
      #expect(result.data == transformed)
    }
    let captured = try #require(await middleware.getLastCapturedResponse())
    #expect(captured.response.body == HTTPBody(Data("payload".utf8)))
  }
}
#endif
