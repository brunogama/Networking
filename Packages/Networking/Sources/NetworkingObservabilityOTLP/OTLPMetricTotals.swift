import Foundation
import NetworkingObservability

struct OTLPMetricTotals: Sendable {
  let startedAt: Date
  let timestamp: Date
  let count: UInt64
  let durationSum: Double

  static func recording(
    _ sample: HTTPRequestMetrics,
    previous: Self?
  ) throws(OTLPExportError) -> Self {
    let (count, overflow) = (previous?.count ?? 0).addingReportingOverflow(1)
    let sum = (previous?.durationSum ?? 0) + sample.duration.rawValue
    guard !overflow, sum.isFinite else { throw .invalidPayload }
    return Self(
      startedAt: previous?.startedAt
        ?? sample.timestamp.addingTimeInterval(-sample.duration.rawValue),
      timestamp: max(previous?.timestamp ?? sample.timestamp, sample.timestamp),
      count: count,
      durationSum: sum
    )
  }
}
