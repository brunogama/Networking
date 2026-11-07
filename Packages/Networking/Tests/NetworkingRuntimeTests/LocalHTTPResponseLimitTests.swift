#if os(macOS)
import Foundation
import NetworkingCore
import NetworkingRuntime
import Testing

@Suite("NetworkClient response size limit over HTTP")
struct LocalHTTPResponseLimitTests {
  @Test("A chunked response exceeding the limit is rejected")
  func rejectsOversizedChunkedResponse() async throws {
    let server = try LocalResponseLimitServer()
    defer { server.stop() }
    let client = NetworkClient(maximumResponseBytes: 1024)
    let url = try #require(URL(string: "http://127.0.0.1:\(server.port)/"))
    let request = HTTPRequest(method: .get, url: HTTPRequestURL(url))
    do {
      _ = try await client.execute(request)
      Issue.record("An oversized response was returned")
    } catch {
      guard case .configuration = error.category else {
        Issue.record("Expected a response limit error, got \(error.category)")
        return
      }
    }
  }
}
#endif
