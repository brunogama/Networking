import NetworkingBenchmarksCore
import Testing

struct BenchmarkSummaryTests {
  @Test("Reports median, p95, and transferred bytes per second")
  func summaryStatistics() {
    let summary = BenchmarkSummary(
      samplesMilliseconds: [4, 1, 2, 3, 5],
      bytesTransferred: 1_000,
      durationSeconds: 2
    )

    #expect(summary.medianMilliseconds == 3)
    #expect(summary.p95Milliseconds == 5)
    #expect(summary.bytesPerSecond == 500)
  }

  @Test("Does not report p95 from a single aggregate sample")
  func singleSampleHasNoPercentile() {
    let summary = BenchmarkSummary(
      samplesMilliseconds: [8],
      bytesTransferred: 320,
      durationSeconds: 1
    )

    #expect(summary.p95Milliseconds == nil)
  }

  @Test("Uses midpoint median for even samples and zero for empty input")
  func evenAndEmptySamples() {
    let even = BenchmarkSummary(
      samplesMilliseconds: [8, 2, 6, 4],
      bytesTransferred: 100,
      durationSeconds: 0
    )
    let empty = BenchmarkSummary(
      samplesMilliseconds: [],
      bytesTransferred: 100,
      durationSeconds: 0
    )

    #expect(even.medianMilliseconds == 5)
    #expect(even.p95Milliseconds == 8)
    #expect(even.bytesPerSecond == 0)
    #expect(empty.sampleCount == 0)
    #expect(empty.medianMilliseconds == 0)
    #expect(empty.p95Milliseconds == nil)
  }
}
