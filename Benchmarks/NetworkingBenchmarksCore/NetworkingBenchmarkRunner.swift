import Foundation
import Networking

/// Exercises HTTP request, file transfer, and server-sent event paths.
public struct NetworkingBenchmarkRunner: Sendable {
  private let context: BenchmarkContext

  /// Creates a runner using a local-only session and diagnostics recorder.
  public init(
    baseURL: URL,
    session: URLSession,
    iterations: Int = 25
  ) throws {
    try Self.validate(baseURL: baseURL, iterations: iterations)
    let diagnostics = NetworkDiagnostics(
      capacity: iterations * 3 + 10,
      logs: .none
    )
    let clients = Self.makeClients(session: session, diagnostics: diagnostics)
    let configuration = BenchmarkConfiguration(
      baseURL: baseURL,
      iterations: iterations
    )
    context = BenchmarkContext(
      configuration: configuration,
      clients: clients,
      diagnostics: diagnostics
    )
  }

  private static func makeClients(
    session: URLSession,
    diagnostics: NetworkDiagnostics
  ) -> BenchmarkClients {
    let client = NetworkClient(
      session: session,
      middleware: HTTPMiddleware(),
      configuration: .init(diagnostics: diagnostics)
    )
    let events = SSEClient(session: session, diagnostics: diagnostics)
    return BenchmarkClients(http: client, events: events)
  }

  /// Runs workloads serially so sample timings remain interpretable.
  public func run() async throws -> [BenchmarkResult] {
    let request = try await HTTPRequestBenchmark(context: context).run()
    let upload = try await HTTPUploadBenchmark(context: context).run()
    let download = try await HTTPDownloadBenchmark(context: context).run()
    let stream = try await SSEBenchmark(context: context).run()
    let progress = try await TransferProgressBenchmarks(context: context).run()
    return [request, upload, download, stream] + progress
  }

  private static func validate(baseURL: URL, iterations: Int) throws {
    let host = baseURL.host?.lowercased() ?? ""
    let isLoopback = ["localhost", "127.0.0.1"].contains(host)
    let isHTTP = ["http", "https"].contains(baseURL.scheme)
    guard isLoopback, isHTTP, iterations > 0 else {
      throw BenchmarkFailure.invalidConfiguration
    }
  }
}

/// Errors raised before a benchmark can safely run.
public enum BenchmarkFailure: Error {
  case invalidConfiguration
}
