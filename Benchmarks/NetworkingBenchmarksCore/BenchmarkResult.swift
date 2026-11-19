import Foundation

/// One operation's measurements and negotiated network protocols.
public struct BenchmarkResult: Codable, Sendable, Equatable, Identifiable {
  /// Stable operation label shown in the report.
  public let name: String
  /// Aggregated timings and throughput.
  public let summary: BenchmarkSummary
  /// Protocols reported by URLSessionTaskMetrics.
  public let protocolsObserved: [String]

  /// Identifies this result by operation name.
  public var id: String { name }

  /// Creates a result for one operation.
  public init(
    name: String,
    summary: BenchmarkSummary,
    protocolsObserved: [String]
  ) {
    self.name = name
    self.summary = summary
    self.protocolsObserved = protocolsObserved
  }
}
