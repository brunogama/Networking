import Foundation
import NetworkingCore

/// One completed request measurement without URL, headers, or body data.
public struct HTTPRequestMetrics: Sendable, Equatable {

  /// Completion time of the measured request.
  public let timestamp: Date
  /// Nonnegative, finite elapsed time in seconds.
  public let duration: MeasurementDuration
  /// The completed request outcome.
  public let outcome: Outcome

  /// Rejects invalid durations and timestamps at the measurement boundary.
  public init(
    timestamp: Date = Date(),
    duration: MeasurementDuration,
    outcome: Outcome
  )
    throws(ValidationError)
  {
    guard duration.rawValue.isFinite, duration.rawValue >= 0 else {
      throw .invalidDuration
    }
    guard timestamp.timeIntervalSince1970.isFinite else { throw .invalidTimestamp }
    self.timestamp = timestamp
    self.duration = duration
    self.outcome = outcome
  }
}
