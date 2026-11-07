import Foundation
import NetworkingCore
import NetworkingTesting
import Testing
@testable import NetworkingRuntime

@Suite("HTTP diagnostics")
struct NetworkDiagnosticsTests {
  @Test("Client records a real transport attempt and redacts secrets by default")
  func requestAndResponse() async throws {
    let diagnostics = NetworkDiagnostics(logs: .none)
    let (client, request) = try makeClient(diagnostics: diagnostics)
    let response = try await client.execute(request)
    #expect(response.status == .ok)
    let trace = try #require(diagnostics.traces.first)
    #expect(trace.response?.statusCode == 200)
    #expect(trace.request.headers["Authorization"] == "<redacted>")
    #expect(trace.request.url?.query?.contains("secret") == false)
    #expect(trace.request.body == nil)
    #expect(trace.response?.body == nil)
    #expect(trace.endedAt != nil)
    #expect(trace.failure == nil)
  }

  @Test("Each attempt has its own identity and retention is bounded")
  func boundedAttempts() async throws {
    var privacy = HTTPTracePrivacy()
    privacy.capturesBodies = true
    privacy.maximumBodyBytes = 2
    let diagnostics = NetworkDiagnostics(capacity: 2, privacy: privacy, logs: .none)
    let request = try request()
    let first = diagnostics.start(request)
    let second = diagnostics.start(request)
    let third = diagnostics.start(request)
    diagnostics.finish(
      third,
      response: HTTPResponse(
        request: request,
        status: .ok,
        body: HTTPBody(Data("response".utf8))
      )
    )
    #expect(first != second)
    #expect(diagnostics.traces.map(\.id) == [second, third])
    #expect(diagnostics.traces.last?.response?.body == Data("re".utf8))
    #expect(diagnostics.traces.last?.request.body == Data("re".utf8))
    let exported = try diagnostics.export()
    #expect(String(data: exported, encoding: .utf8)?.contains("secret") == false)
    diagnostics.clear()
    #expect(diagnostics.traces.isEmpty)
  }

  @Test("Terminal failures are recorded without retaining arbitrary error messages")
  func failedAttempt() async throws {
    let diagnostics = NetworkDiagnostics(logs: .none)
    let exchange = HTTPExchange<ExchangePrepared>(diagnostics: diagnostics).start(try request())
    exchange.fail(URLError(.cancelled))
    let trace = try #require(diagnostics.traces.first)
    #expect(trace.failure == "NSURLErrorDomain:-999")
    #expect(trace.endedAt != nil)
  }

  @Test("Concurrent callers preserve unique identities and the retention bound")
  func concurrentRecording() async throws {
    let diagnostics = NetworkDiagnostics(capacity: 8, logs: .none)
    let request = try request()
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<32 {
        group.addTask {
          let exchange = HTTPExchange<ExchangePrepared>(diagnostics: diagnostics).start(request)
          exchange.finish(HTTPResponse(request: request, status: .ok, body: HTTPBody(Data())))
        }
      }
    }
    #expect(diagnostics.traces.count == 8)
    #expect(Set(diagnostics.traces.map(\.id)).count == 8)
    #expect(diagnostics.traces.allSatisfy { $0.endedAt != nil })
  }

  @Test("A subscriber receives a change without an unowned background task")
  func observation() async throws {
    let diagnostics = NetworkDiagnostics(logs: .none)
    var changes = diagnostics.changes().makeAsyncIterator()
    _ = await changes.next()
    _ = diagnostics.start(try request())
    #expect(await changes.next() != nil)
    #expect(diagnostics.traces.count == 1)
  }

  private func request() throws -> HTTPRequest {
    let url = try #require(URL(string: "https://example.test/trace?token=secret"))
    return HTTPRequest(
      method: .post,
      url: HTTPRequestURL(url),
      headers: ["Authorization": "secret"],
      body: HTTPBody(Data("request".utf8))
    )
  }

  private func makeClient(
    diagnostics: NetworkDiagnostics
  ) throws -> (NetworkClient, HTTPRequest) {
    let request = try request()
    let context = MockContextIdentifier()
    MockURLProtocol.stubSequential(
      url: request.url,
      responses: [.success(statusCode: 200, data: HTTPBody(Data("response".utf8)))],
      contextID: context
    )
    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: context)
    )
    let client = NetworkClient(
      session: session,
      middleware: HTTPMiddleware(),
      configuration: .init(diagnostics: diagnostics)
    )
    return (client, request)
  }
}
