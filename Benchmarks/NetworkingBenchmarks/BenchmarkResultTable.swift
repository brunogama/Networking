import Foundation
import NetworkingBenchmarksCore
import SwiftUI

struct BenchmarkResultTable: View {
  let results: [BenchmarkResult]

  var body: some View {
    Table(results) {
      TableColumn("Operation", value: \.name)
      TableColumn("Samples") { Text("\($0.summary.sampleCount)") }
      TableColumn("Median") { Text(formattedMedian($0)) }
      TableColumn("p95 (2+ samples)") { Text(formattedP95($0)) }
      TableColumn("Protocol") { Text(formattedProtocols($0)) }
      TableColumn("Throughput") { Text(formattedThroughput($0)) }
    }
    .frame(minHeight: 240)
  }

  private func formattedMedian(_ benchmarkResult: BenchmarkResult) -> String {
    String(format: "%.2f ms", benchmarkResult.summary.medianMilliseconds)
  }

  private func formattedP95(_ benchmarkResult: BenchmarkResult) -> String {
    benchmarkResult.summary.p95Milliseconds.map {
      String(format: "%.2f ms", $0)
    } ?? "N/A"
  }

  private func formattedProtocols(
    _ benchmarkResult: BenchmarkResult
  ) -> String {
    let protocols = benchmarkResult.protocolsObserved.joined(separator: ", ")
    return protocols.isEmpty ? "unknown" : protocols
  }

  private func formattedThroughput(
    _ benchmarkResult: BenchmarkResult
  ) -> String {
    let bytesPerSecond = Int64(benchmarkResult.summary.bytesPerSecond)
    let formatted = ByteCountFormatter.string(
      fromByteCount: bytesPerSecond,
      countStyle: .memory
    )
    return formatted + "/s"
  }
}
