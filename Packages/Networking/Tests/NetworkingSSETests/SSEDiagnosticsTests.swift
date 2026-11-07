import Foundation
import NetworkingCore
import NetworkingRuntime
import NetworkingSSE
import Testing

@Suite("SSE transport diagnostics")
struct SSEDiagnosticsTests {
  @Test("A completed SSE stream records a sanitized terminal trace")
  func completedStream() async throws {
    let (server, url) = try await makeServer(
      path: "/sse/diagnostics",
      scripts: [SSETestResponseScript(chunks: [SSETestChunk("data: example\n\n")])]
    )
    defer { server.stop() }
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let diagnostics = NetworkDiagnostics(logs: .none)
    let client = SSEClient(session: session, diagnostics: diagnostics)
    let request = makeRequest(url: url, headers: ["Authorization": "secret"])
    for try await _ in client.connect(
      request,
      configuration: SSEConfiguration(reconnectMode: .disabled)
    ) {}
    let trace = try #require(diagnostics.traces.first)
    #expect(diagnostics.traces.count == 1)
    #expect(trace.endedAt != nil)
    #expect(trace.failure == nil)
    #expect(trace.response?.statusCode == 200)
    #expect(trace.request.headers["Authorization"] == "<redacted>")
  }
}
