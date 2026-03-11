import Foundation
import NetworkingCore

extension TransferControls {
  /// Actor that enforces bandwidth limits across transfers.
  public actor BandwidthThrottler {
    private var transferLimits: [UUID: BandwidthLimit] = [:]
    private var transferUsage: [UUID: BandwidthUsage] = [:]
    private let globalLimit: BandwidthLimit?

    private struct BandwidthUsage {
      var bytesInWindow: Double = 0
      var windowStart = Date()
      var lastUpdate = Date()

      mutating func resetWindow() {
        bytesInWindow = 0
        windowStart = Date()
      }

      mutating func addBytes(_ bytes: Double, at time: Date = Date()) {
        let windowDuration = time.timeIntervalSince(windowStart)
        if windowDuration >= 1.0 {
          resetWindow()
        }
        bytesInWindow += bytes
        lastUpdate = time
      }

      func currentRate() -> Double {
        let windowDuration = max(Date().timeIntervalSince(windowStart), 0.1)
        return bytesInWindow / windowDuration
      }
    }

    public init(globalLimit: BandwidthLimit? = nil) {
      self.globalLimit = globalLimit
    }

    /// Sets bandwidth limit for a specific transfer.
    /// - Parameters:
    ///   - transferId: Transfer identifier
    ///   - limit: Bandwidth limit to apply
    public func setBandwidthLimit(for transferId: TransferIdentifier, limit: BandwidthLimit?) {
      if let limit = limit {
        transferLimits[transferId.rawValue] = limit
        if transferUsage[transferId.rawValue] == nil {
          transferUsage[transferId.rawValue] = BandwidthUsage()
        }
      } else {
        transferLimits.removeValue(forKey: transferId.rawValue)
        transferUsage.removeValue(forKey: transferId.rawValue)
      }
    }

    /// Checks if a transfer can send/receive bytes without exceeding limits.
    /// - Parameters:
    ///   - transferId: Transfer identifier
    ///   - bytes: Number of bytes to transfer
    ///   - direction: Transfer direction
    /// - Returns: Whether the transfer is allowed and suggested delay
    public func checkBandwidthLimit(
      for transferId: TransferIdentifier,
      bytes: TransferByteCount,
      direction: BandwidthLimit.Direction
    ) -> BandwidthCheckResult {
      let byteCount = Double(bytes.rawValue)

      if let transferResult = transferSpecificLimitResult(
        for: transferId,
        byteCount: byteCount,
        direction: direction
      ) {
        return transferResult
      }

      if let globalResult = globalLimitResult(byteCount: byteCount, direction: direction) {
        return globalResult
      }

      return BandwidthCheckResult(allowed: true, suggestedDelay: 0)
    }

    private func transferSpecificLimitResult(
      for transferId: TransferIdentifier,
      byteCount: Double,
      direction: BandwidthLimit.Direction
    ) -> BandwidthCheckResult? {
      guard
        let limit = transferLimits[transferId.rawValue],
        let usage = transferUsage[transferId.rawValue]
      else {
        return nil
      }

      guard directionMatches(limit.direction, requestedDirection: direction) else {
        return BandwidthCheckResult(allowed: true, suggestedDelay: 0)
      }

      return limitExceededResult(
        currentRate: usage.currentRate(),
        byteCount: byteCount,
        limit: limit
      )
    }

    private func globalLimitResult(
      byteCount: Double,
      direction: BandwidthLimit.Direction
    ) -> BandwidthCheckResult? {
      guard let globalLimit else { return nil }
      guard directionMatches(globalLimit.direction, requestedDirection: direction) else {
        return nil
      }

      let totalRate = transferUsage.values.reduce(0) { $0 + $1.currentRate() }
      return limitExceededResult(
        currentRate: totalRate,
        byteCount: byteCount,
        limit: globalLimit
      )
    }

    private func directionMatches(
      _ configuredDirection: BandwidthLimit.Direction,
      requestedDirection: BandwidthLimit.Direction
    ) -> Bool {
      configuredDirection == .both || configuredDirection == requestedDirection
    }

    private func limitExceededResult(
      currentRate: Double,
      byteCount: Double,
      limit: BandwidthLimit
    ) -> BandwidthCheckResult? {
      let projectedRate = currentRate + (byteCount / limit.timeWindow.rawValue)
      guard projectedRate > limit.bytesPerSecond.rawValue else { return nil }

      let excessRate = projectedRate - limit.bytesPerSecond.rawValue
      let delay = excessRate / limit.bytesPerSecond.rawValue * limit.timeWindow.rawValue
      return BandwidthCheckResult(allowed: false, suggestedDelay: TransferDuration(delay))
    }

    /// Records bandwidth usage for a transfer.
    /// - Parameters:
    ///   - transferId: Transfer identifier
    ///   - bytes: Bytes transferred
    public func recordBandwidthUsage(for transferId: TransferIdentifier, bytes: TransferByteCount) {
      if transferUsage[transferId.rawValue] != nil {
        transferUsage[transferId.rawValue]?.addBytes(Double(bytes.rawValue))
      } else if transferLimits[transferId.rawValue] != nil {
        var usage = BandwidthUsage()
        usage.addBytes(Double(bytes.rawValue))
        transferUsage[transferId.rawValue] = usage
      }
    }

    /// Removes transfer from bandwidth tracking.
    /// - Parameter transferId: Transfer identifier
    public func removeTransfer(_ transferId: TransferIdentifier) {
      transferLimits.removeValue(forKey: transferId.rawValue)
      transferUsage.removeValue(forKey: transferId.rawValue)
    }
  }
}
