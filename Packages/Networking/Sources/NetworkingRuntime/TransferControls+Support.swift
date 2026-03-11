import Foundation
import NetworkingCore

extension TransferControls {
  /// Configuration for transfer control manager.
  public struct TransferControlConfiguration: Sendable {
    /// Maximum number of concurrent active transfers.
    public let maxConcurrentTransfers: TransferConcurrencyLimit

    /// Default bandwidth limit applied to all transfers.
    public let defaultBandwidthLimit: BandwidthLimit?

    /// Automatic retry configuration for failed transfers.
    public let autoRetryConfiguration: AutoRetryConfiguration?

    /// Whether to automatically manage transfer priorities based on system load.
    public let enableAdaptivePriority: AdaptivePriorityFlag

    public init(
      maxConcurrentTransfers: TransferConcurrencyLimit = 4,
      defaultBandwidthLimit: BandwidthLimit? = nil,
      autoRetryConfiguration: AutoRetryConfiguration? = nil,
      enableAdaptivePriority: AdaptivePriorityFlag = false
    ) {
      self.maxConcurrentTransfers = maxConcurrentTransfers
      self.defaultBandwidthLimit = defaultBandwidthLimit
      self.autoRetryConfiguration = autoRetryConfiguration
      self.enableAdaptivePriority = enableAdaptivePriority
    }

    public static let `default` = Self()
  }

  /// Configuration for automatic retry behavior.
  public struct AutoRetryConfiguration: Sendable {
    public let maxRetries: TransferRetryCount
    public let baseDelay: RetryDelay
    public let backoffMultiplier: BackoffMultiplier
    public let maxDelay: RetryDelay

    public init(
      maxRetries: TransferRetryCount = 3,
      baseDelay: RetryDelay = 1.0,
      backoffMultiplier: BackoffMultiplier = 2.0,
      maxDelay: RetryDelay = 60.0
    ) {
      self.maxRetries = maxRetries
      self.baseDelay = baseDelay
      self.backoffMultiplier = backoffMultiplier
      self.maxDelay = maxDelay
    }
  }

  /// Public transfer information.
  public struct TransferInfo: Sendable {
    public let transferId: TransferIdentifier
    public let state: TransferState
    public let priority: TransferPriority
    public let bandwidthLimit: BandwidthLimit?
    public let totalDuration: TransferDuration
    public let activeDuration: TransferDuration
    public let pauseCount: TransferPauseCount
    public let resumeCount: TransferResumeCount

    /// Efficiency ratio (active time / total time).
    public var efficiency: TransferEfficiencyValue {
      guard totalDuration.rawValue > 0 else { return 0 }
      return TransferEfficiencyValue(activeDuration.rawValue / totalDuration.rawValue)
    }
  }

  /// Statistics about all managed transfers.
  public struct TransferStatistics: Sendable {
    public let totalTransfers: TransferCount
    public let activeTransfers: TransferCount
    public let pausedTransfers: TransferCount
    public let completedTransfers: TransferCount
    public let failedTransfers: TransferCount
    public let stateDistribution: [TransferState: TransferCount]
    public let priorityDistribution: [TransferPriority: TransferCount]
    public let averageActiveDuration: TransferDuration

    /// Success rate percentage.
    public var successRate: TransferSuccessRate {
      let totalFinished = completedTransfers.rawValue + failedTransfers.rawValue
      guard totalFinished > 0 else { return 0 }
      return TransferSuccessRate(Double(completedTransfers.rawValue) / Double(totalFinished) * 100)
    }
  }
}
