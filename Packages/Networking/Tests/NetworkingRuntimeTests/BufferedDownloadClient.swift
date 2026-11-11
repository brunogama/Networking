#if os(macOS)
import NetworkingCore
import NetworkingRuntime

struct BufferedDownloadClient: HTTPClient {
  let client: NetworkClient

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    try await client.execute(request)
  }
}
#endif
