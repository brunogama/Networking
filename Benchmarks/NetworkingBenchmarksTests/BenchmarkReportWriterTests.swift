import Foundation
import Testing
@testable import NetworkingBenchmarksCore

struct BenchmarkReportWriterTests {
  @Test("Writes JSON that can be decoded back into benchmark results")
  func writesReadableReport() throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let reportURL = directory.appending(path: "report.json")
    let expected = [makeResult()]

    try BenchmarkReportWriter.write(expected, to: reportURL)
    let reportData = try Data(contentsOf: reportURL)
    let actual = try JSONDecoder().decode(
      [BenchmarkResult].self,
      from: reportData
    )

    #expect(actual == expected)
  }

  @Test("Propagates a report write failure")
  func propagatesWriteFailure() {
    let reportURL = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString)
      .appending(path: "report.json")

    #expect(throws: Error.self) {
      try BenchmarkReportWriter.write([], to: reportURL)
    }
  }

  private func makeResult() -> BenchmarkResult {
    let summary = BenchmarkSummary(
      samplesMilliseconds: [1, 2, 3],
      bytesTransferred: 512,
      durationSeconds: 0.003
    )
    return BenchmarkResult(
      name: "HTTP request",
      summary: summary,
      protocolsObserved: ["h2"]
    )
  }
}
