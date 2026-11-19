import Foundation
import Networking
import os

struct BenchmarkConfiguration: Sendable {
  let baseURL: URL
  let iterations: Int
}

struct BenchmarkClients: Sendable {
  let http: NetworkClient
  let events: SSEClient
}

struct BenchmarkMeasurement: Sendable {
  let name: String
  let samplesMilliseconds: [Double]
  let bytesTransferred: Int64
  let durationSeconds: Double
}

enum BenchmarkTiming {
  static func milliseconds(_ duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds) * 1_000
      + Double(components.attoseconds) / 1_000_000_000_000_000
  }

  static func seconds(_ duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds)
      + Double(components.attoseconds) / 1_000_000_000_000_000_000
  }
}

enum BenchmarkFiles {
  private static let logger = Logger(
    subsystem: "NetworkingBenchmarks",
    category: "files"
  )

  static func create(byteCount: Int, prefix: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
    let name = "\(prefix)-\(UUID().uuidString)"
    let fileURL = directory.appendingPathComponent(name)
    let payload = Data(repeating: 0x5A, count: byteCount)
    try payload.write(to: fileURL, options: .atomic)
    return fileURL
  }

  static func remove(_ fileURL: URL) {
    do {
      try FileManager.default.removeItem(at: fileURL)
    } catch {
      let message = error.localizedDescription
      logger.error("Could not remove benchmark fixture: \(message, privacy: .public)")
    }
  }
}

struct BenchmarkContext: Sendable {
  let configuration: BenchmarkConfiguration
  let clients: BenchmarkClients
  let diagnostics: NetworkDiagnostics

  func makeRequest(_ path: String, method: HTTPMethod = .get) -> HTTPRequest {
    let url = configuration.baseURL.appending(path: path)
    return HTTPRequest(method: method, url: url)
  }

  func makeResult(_ measurement: BenchmarkMeasurement) -> BenchmarkResult {
    let connections = diagnostics.traces.flatMap(\.connections)
    let protocols = connections.compactMap(\.protocolName)
    let uniqueProtocols = Set(protocols).sorted()
    let summary = BenchmarkSummary(
      samplesMilliseconds: measurement.samplesMilliseconds,
      bytesTransferred: measurement.bytesTransferred,
      durationSeconds: measurement.durationSeconds
    )
    return BenchmarkResult(
      name: measurement.name,
      summary: summary,
      protocolsObserved: uniqueProtocols
    )
  }
}
