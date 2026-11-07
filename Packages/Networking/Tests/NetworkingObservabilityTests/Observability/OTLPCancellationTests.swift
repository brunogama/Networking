import Foundation
import NetworkingCore
import NetworkingObservability
import NetworkingObservabilityOTLP
import os
import Testing

@Suite("OTLP cancellation ownership")
struct OTLPCancellationTests {
  @Test("Cancelling an export stops the active URLSession request before its task exits")
  func cancelsActiveTransport() async throws {
    let endpoint = try #require(URL(string: "https://\(UUID().uuidString).example"))
    let events = PendingOTLPProtocol.register(endpoint)
    defer { PendingOTLPProtocol.remove(endpoint) }
    let sessionConfiguration = URLSessionConfiguration.ephemeral
    sessionConfiguration.protocolClasses = [PendingOTLPProtocol.self]
    let session = URLSession(configuration: sessionConfiguration)
    defer { session.invalidateAndCancel() }
    let exporter = try OTLPTraceExporter(
      configuration: OTLPConfiguration(endpoint: HTTPRequestURL(endpoint)),
      session: session
    )
    let span = TraceSpan(name: "cancel", context: TraceContext())
    await span.end()
    let operation = Task { try await exporter.export(span) }
    var iterator = events.makeAsyncIterator()
    #expect(await iterator.next() == .started)
    operation.cancel()
    await #expect(throws: OTLPExportError.cancelled) { try await operation.value }
    #expect(await iterator.next() == .stopped)
  }
}
