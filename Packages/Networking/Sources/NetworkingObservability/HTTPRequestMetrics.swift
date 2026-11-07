import Foundation
import NetworkingCore

/// One completed request measurement without URL, headers, or body data.
public struct HTTPRequestMetrics: Sendable, Equatable {

  public let timestamp: Date

  public let duration: MeasurementDuration

  public let outcome: Outcome

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
