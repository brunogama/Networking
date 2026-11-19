import Foundation

/// Aggregated latency and throughput measurements for one benchmark operation.
public struct BenchmarkSummary: Codable, Sendable, Equatable {
  /// The number of measured operations.
  public let sampleCount: Int
  /// Median elapsed time for one operation in milliseconds.
  public let medianMilliseconds: Double
  /// The 95th-percentile elapsed time in milliseconds.
  public let p95Milliseconds: Double?
  /// Payload throughput over the complete measurement interval.
  public let bytesPerSecond: Double

  /// Summarizes measured samples using nearest-rank p95.
  public init(
    samplesMilliseconds: [Double],
    bytesTransferred: Int64,
    durationSeconds: Double
  ) {
    let ordered = samplesMilliseconds.sorted()
    sampleCount = ordered.count
    medianMilliseconds = Self.median(ordered)
    p95Milliseconds = Self.percentile(0.95, from: ordered)
    bytesPerSecond =
      durationSeconds > 0
      ? Double(max(0, bytesTransferred)) / durationSeconds
      : 0
  }

  private static func median(_ samples: [Double]) -> Double {
    guard !samples.isEmpty else { return 0 }
    let middle = samples.count / 2
    guard samples.count.isMultiple(of: 2) else { return samples[middle] }
    return (samples[middle - 1] + samples[middle]) / 2
  }

  private static func percentile(
    _ value: Double,
    from samples: [Double]
  ) -> Double? {
    guard samples.count > 1 else { return nil }
    let sampleCount = Double(samples.count)
    let scaledRank = value * sampleCount
    let roundedRank = Int(scaledRank.rounded(.up))
    let rank = max(1, roundedRank)
    let boundedRank = min(samples.count, rank)
    let lastIndex = boundedRank - 1
    return samples[lastIndex]
  }
}
