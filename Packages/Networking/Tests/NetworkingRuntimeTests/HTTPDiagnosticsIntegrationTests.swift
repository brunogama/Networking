#if os(macOS)
import Foundation
import NetworkingCore
import Testing
@testable import NetworkingRuntime

@Suite("URLSession connection diagnostics")
struct HTTPDiagnosticsIntegrationTests {
  @Test("Ticket cancellation closes the URLSession connection before leaving its scope")
  func ticketCancellationClosesConnection() async throws {
    let server = try HTTPDiagnosticsServer()
    defer { server.stop() }
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let diagnostics = NetworkDiagnostics(logs: .none)
    let client = NetworkClient(
      session: session,
      middleware: HTTPMiddleware(),
      configuration: .init(diagnostics: diagnostics)
    )
    let cancelled = try await client.withRequest(request(server, path: "wait")) { ticket in
      let cancellation = ticket.cancellation
      let event = try await server.nextEvent()
      #expect(event == "started")
      #expect(cancellation.cancel())
      do throws(HTTPError) {
        _ = try await ticket.response()
        return false
      } catch {
        return error.category == .cancelled
      }
    }
    #expect(cancelled)
    #expect(try await server.nextEvent() == "disconnected")
    let trace = try #require(diagnostics.traces.first)
    #expect(trace.endedAt != nil)
    #expect(trace.failure != nil)
  }

  @Test("Loopback redirects, uploads, and downloads report real connection metrics")
  func nativeConnections() async throws {
    let server = try HTTPDiagnosticsServer()
    defer { server.stop() }
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    var privacy = HTTPTracePrivacy()
    privacy.capturesBodies = true
    privacy.maximumBodyBytes = 4
    let diagnostics = NetworkDiagnostics(privacy: privacy, logs: .none)
    let client = NetworkClient(
      session: session,
      middleware: HTTPMiddleware(),
      configuration: .init(diagnostics: diagnostics)
    )
    let response = try await client.execute(request(server, path: "redirect"))
    #expect(response.status == .ok)
    let redirected = try #require(diagnostics.traces.first)
    #expect(redirected.connections.count == 2)
    #expect(redirected.response?.url?.path == "/payload")
    #expect(redirected.response?.body == Data("payl".utf8))
    try await assertTransfers(client, server: server)
    #expect(diagnostics.traces.count == 3)
    #expect(diagnostics.traces.allSatisfy { !$0.connections.isEmpty })
    #expect(diagnostics.traces.allSatisfy { $0.failure == nil && $0.endedAt != nil })
  }

  private func assertTransfers(_ client: NetworkClient, server: HTTPDiagnosticsServer) async throws
  {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try Data("upload".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    let upload = try await client.upload(
      request(server, path: "upload", method: .post),
      fromFile: file,
      progress: nil
    )
    #expect(upload.body?.rawValue == Data("upload".utf8))
    let download = try await client.download(request(server, path: "download"), progress: nil)
    defer { try? FileManager.default.removeItem(at: download.temporaryFileURL) }
    #expect(try Data(contentsOf: download.temporaryFileURL) == Data("payload".utf8))
  }

  private func request(
    _ server: HTTPDiagnosticsServer,
    path: String,
    method: HTTPMethod = .get
  ) -> HTTPRequest {
    HTTPRequest(method: method, url: HTTPRequestURL(server.baseURL.appendingPathComponent(path)))
  }
}
#endif
