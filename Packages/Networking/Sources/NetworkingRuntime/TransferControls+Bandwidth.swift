import Foundation
import NetworkingCore

extension TransferControls {
  /// Priority levels for transfer operations.
  public enum TransferPriority: Sendable, CaseIterable, Comparable {
    case background
    case low
    case normal
    case high
    case critical

    public var rank: TransferPriorityRank {
      switch self {
      case .background: return 0
      case .low: return 1
      case .normal: return 2
      case .high: return 3
      case .critical: return 4
      }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.rank.rawValue < rhs.rank.rawValue
    }

    public var description: String {
      switch self {
      case .background: return "Background"
      case .low: return "Low"
      case .normal: return "Normal"
      case .high: return "High"
      case .critical: return "Critical"
      }
    }
  }

  /// Bandwidth limitation configuration.
  public struct BandwidthLimit: Sendable, Hashable {
    /// Maximum bytes per second.
    public let bytesPerSecond: TransferByteRate

    /// Whether the limit applies to upload, download, or both.
    public let direction: Direction

    /// Time window for rate calculation (in seconds).
    public let timeWindow: TransferTimeWindow

    public enum Direction: Sendable, CaseIterable {
      case upload
      case download
      case both

      public var identifier: TransferDirectionName {
        switch self {
        case .upload: return "upload"
        case .download: return "download"
        case .both: return "both"
        }
      }
    }

    public init(
      bytesPerSecond: TransferByteRate,
      direction: Direction = .both,
      timeWindow: TransferTimeWindow = 1.0
    ) {
      self.bytesPerSecond = bytesPerSecond
      self.direction = direction
      self.timeWindow = timeWindow
    }

    /// Convenience initializer for MB/s.
    public static func megabytesPerSecond(
      _ mbps: TransferSpeed,
      direction: Direction = .both
    ) -> Self {
      Self(bytesPerSecond: TransferByteRate(mbps.rawValue * 1_048_576), direction: direction)
    }

    /// Convenience initializer for KB/s.
    public static func kilobytesPerSecond(
      _ kbps: TransferSpeed,
      direction: Direction = .both
    ) -> Self {
      Self(bytesPerSecond: TransferByteRate(kbps.rawValue * 1024), direction: direction)
    }

    /// Human-readable description.
    public var description: String {
      let speed: String
      if bytesPerSecond.rawValue >= 1_048_576 {
        speed = String(format: "%.1f MB/s", bytesPerSecond.rawValue / 1_048_576)
      } else if bytesPerSecond.rawValue >= 1024 {
        speed = String(format: "%.1f KB/s", bytesPerSecond.rawValue / 1024)
      } else {
        speed = String(format: "%.0f B/s", bytesPerSecond.rawValue)
      }
      return "\(speed) (\(direction.identifier.rawValue))"
    }
  }

  public struct BandwidthCheckResult: Sendable, Hashable {
    public let allowed: TransferAllowanceFlag
    public let suggestedDelay: TransferDuration

    public init(
      allowed: TransferAllowanceFlag,
      suggestedDelay: TransferDuration
    ) {
      self.allowed = allowed
      self.suggestedDelay = suggestedDelay
    }
  }
}

extension TransferControls.BandwidthLimit: CustomStringConvertible {}
