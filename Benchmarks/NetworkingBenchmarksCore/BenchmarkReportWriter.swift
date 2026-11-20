import Foundation

/// Encodes benchmark results as an atomic JSON report.
public enum BenchmarkReportWriter {
  /// Writes the results to the destination URL or propagates an encoding or I/O error.
  public static func write(_ results: [BenchmarkResult], to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let reportData = try encoder.encode(results)
    try reportData.write(to: url, options: .atomic)
  }
}
