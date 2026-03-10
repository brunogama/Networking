import Foundation
import NetworkingCore

// swiftlint:disable file_length
/// Advanced transfer control system providing pause/resume functionality,
/// state management, and bandwidth throttling capabilities.
public struct TransferControls: Sendable {  // swiftlint:disable:this type_body_length
  // MARK: - Transfer State Management

  /// Transfer states that control the flow and behavior of active transfers
  public enum TransferState: Sendable, CaseIterable, Hashable {
    case waiting
    case preparing
    case active
    case paused
    case resuming
    case cancelling
    case cancelled
    case completed
    case failed

    public var identifier: TransferStateName {
      switch self {
      case .waiting: return "waiting"
      case .preparing: return "preparing"
      case .active: return "active"
      case .paused: return "paused"
      case .resuming: return "resuming"
      case .cancelling: return "cancelling"
      case .cancelled: return "cancelled"
      case .completed: return "completed"
      case .failed: return "failed"
      }
    }

    /// Whether the transfer is currently processing data
    public var isActive: TransferActivityFlag {
      switch self {
      case .active, .resuming:
        return true

      case .waiting, .preparing, .paused, .cancelling, .cancelled, .completed, .failed:
        return false
      }
    }

    /// Whether the transfer can be paused
    public var canPause: TransferPauseCapabilityFlag {
      switch self {
      case .active, .resuming:
        return true

      case .waiting, .preparing, .paused, .cancelling, .cancelled, .completed, .failed:
        return false
      }
    }

    /// Whether the transfer can be resumed
    public var canResume: TransferResumeCapabilityFlag {
      switch self {
      case .paused:
        return true

      case .waiting, .preparing, .active, .resuming, .cancelling, .cancelled, .completed, .failed:
        return false
      }
    }

    /// Whether the transfer can be cancelled
    public var canCancel: TransferCancelCapabilityFlag {
      switch self {
      case .waiting, .preparing, .active, .paused, .resuming:
        return true

      case .cancelling, .cancelled, .completed, .failed:
        return false
      }
    }
  }

  /// Transfer control actions that can be performed
  public enum ControlAction: Sendable, CaseIterable {
    case pause
    case resume
    case cancel
    case restart
    case prioritize
    case throttle

    public var identifier: TransferControlActionName {
      switch self {
      case .pause: return "pause"
      case .resume: return "resume"
      case .cancel: return "cancel"
      case .restart: return "restart"
      case .prioritize: return "prioritize"
      case .throttle: return "throttle"
      }
    }
  }

  /// Errors that can occur during transfer control operations
  public enum TransferControlError: Error, LocalizedError {
    case invalidStateTransition(from: TransferState, to: TransferState)
    case transferNotFound(TransferIdentifier)
    case actionNotAllowed(ControlAction, currentState: TransferState)
    case invalidBandwidthLimit(TransferByteRate)
    case resumeDataCorrupted
    case concurrencyLimitExceeded(limit: TransferConcurrencyLimit)

    public var errorDescription: String? {
      switch self {
      case .invalidStateTransition(let from, let to):
        return
          "Invalid state transition from \(from.identifier.rawValue) to \(to.identifier.rawValue)"

      case .transferNotFound(let id):
        return "Transfer with ID \(id.rawValue) not found"

      case .actionNotAllowed(let action, let state):
        return
          "Action '\(action.identifier.rawValue)' not allowed in state '\(state.identifier.rawValue)'"

      case .invalidBandwidthLimit(let limit):
        return "Invalid bandwidth limit: \(limit.rawValue) bytes/sec"

      case .resumeDataCorrupted:
        return "Resume data is corrupted and cannot be used"

      case .concurrencyLimitExceeded(let limit):
        return "Concurrency limit of \(limit) transfers exceeded"
      }
    }
  }

  // MARK: - Transfer Control Manager

  /// Actor-based manager that handles transfer state and control operations
  public actor TransferControlManager {  // swiftlint:disable:this type_body_length
    /// Information about an active transfer and its control state
    private struct TransferControlInfo {
      let transferId: UUID
      var state: TransferState
      var priority: TransferPriority
      var bandwidthLimit: BandwidthLimit?
      var resumeData: Data?
      var pauseTime: Date?
      var totalPausedDuration: TimeInterval = 0
      let creationTime = Date()
      var lastStateChangeTime = Date()
      var pauseCount = 0
      var resumeCount = 0

      /// Total time since transfer was created
      var totalDuration: TimeInterval {
        Date().timeIntervalSince(creationTime)
      }

      /// Active duration (excluding paused time)
      var activeDuration: TimeInterval {
        let currentPausedTime: TimeInterval
        if state == .paused, let pauseTime {
          currentPausedTime = Date().timeIntervalSince(pauseTime)
        } else {
          currentPausedTime = 0
        }
        return totalDuration - totalPausedDuration - currentPausedTime
      }
    }

    private static let validStateTransitions: [TransferState: Set<TransferState>] = [
      .waiting: [.preparing, .cancelled],
      .preparing: [.active, .paused, .cancelled],
      .active: [.paused, .cancelling, .completed, .failed],
      .paused: [.resuming, .cancelling],
      .resuming: [.active, .paused, .failed],
      .cancelling: [.cancelled],
    ]

    private var activeTransfers: [UUID: TransferControlInfo] = [:]
    private let configuration: TransferControlConfiguration

    public init(configuration: TransferControlConfiguration = .default) {
      self.configuration = configuration
    }

    // MARK: - Transfer Registration

    /// Registers a new transfer with the control manager
    /// - Parameters:
    ///   - transferId: Unique identifier for the transfer
    ///   - priority: Initial priority level
    ///   - bandwidthLimit: Optional bandwidth limitation
    /// - Returns: Initial transfer state
    public func registerTransfer(
      _ transferId: TransferIdentifier,
      priority: TransferPriority = .normal,
      bandwidthLimit: BandwidthLimit? = nil
    ) async throws -> TransferState {
      // Check concurrency limits
      let activeCount = activeTransfers.values.filter { $0.state.isActive.rawValue }.count
      if activeCount >= configuration.maxConcurrentTransfers.rawValue {
        throw TransferControlError.concurrencyLimitExceeded(
          limit: configuration.maxConcurrentTransfers
        )
      }

      let controlInfo = TransferControlInfo(
        transferId: transferId.rawValue,
        state: .waiting,
        priority: priority,
        bandwidthLimit: bandwidthLimit
      )

      activeTransfers[transferId.rawValue] = controlInfo

      // Start the transfer if conditions allow
      return try await transitionToState(transferId: transferId, newState: .preparing)
    }

    /// Unregisters a transfer from the control manager
    /// - Parameter transferId: Transfer identifier to remove
    public func unregisterTransfer(_ transferId: TransferIdentifier) async {
      activeTransfers.removeValue(forKey: transferId.rawValue)
    }

    // MARK: - State Management

    /// Gets the current state of a transfer
    /// - Parameter transferId: Transfer identifier
    /// - Returns: Current transfer state, or nil if transfer not found
    public func getTransferState(_ transferId: TransferIdentifier) async -> TransferState? {
      activeTransfers[transferId.rawValue]?.state
    }

    /// Gets comprehensive transfer information
    /// - Parameter transferId: Transfer identifier
    /// - Returns: Transfer info or nil if not found
    public func getTransferInfo(_ transferId: TransferIdentifier) async -> TransferInfo? {
      guard let controlInfo = activeTransfers[transferId.rawValue] else { return nil }

      return TransferInfo(
        transferId: TransferIdentifier(controlInfo.transferId),
        state: controlInfo.state,
        priority: controlInfo.priority,
        bandwidthLimit: controlInfo.bandwidthLimit,
        totalDuration: TransferDuration(controlInfo.totalDuration),
        activeDuration: TransferDuration(controlInfo.activeDuration),
        pauseCount: TransferPauseCount(controlInfo.pauseCount),
        resumeCount: TransferResumeCount(controlInfo.resumeCount)
      )
    }

    /// Transitions a transfer to a new state
    /// - Parameters:
    ///   - transferId: Transfer identifier
    ///   - newState: Target state
    /// - Returns: The new state if successful
    @discardableResult
    public func transitionToState(
      transferId: TransferIdentifier,
      newState: TransferState
    ) async throws -> TransferState {
      guard var controlInfo = activeTransfers[transferId.rawValue] else {
        throw TransferControlError.transferNotFound(transferId)
      }

      // Validate state transition
      guard isValidStateTransition(from: controlInfo.state, to: newState) else {
        throw TransferControlError.invalidStateTransition(from: controlInfo.state, to: newState)
      }

      // Handle special state transitions
      applySpecialTransitionEffects(to: &controlInfo, newState: newState)

      controlInfo.state = newState
      controlInfo.lastStateChangeTime = Date()
      activeTransfers[transferId.rawValue] = controlInfo

      return newState
    }

    private func isValidStateTransition(from: TransferState, to: TransferState) -> Bool {
      Self.validStateTransitions[from, default: []].contains(to)
    }

    private func applySpecialTransitionEffects(
      to controlInfo: inout TransferControlInfo,
      newState: TransferState
    ) {
      switch (controlInfo.state, newState) {
      case (.active, .paused), (.resuming, .paused):
        controlInfo.pauseTime = Date()
        controlInfo.pauseCount += 1

      case (.paused, .resuming), (.paused, .active):
        updateResumeMetrics(for: &controlInfo)

      default:
        break
      }
    }

    private func updateResumeMetrics(for controlInfo: inout TransferControlInfo) {
      if let pauseTime = controlInfo.pauseTime {
        controlInfo.totalPausedDuration += Date().timeIntervalSince(pauseTime)
      }
      controlInfo.pauseTime = nil
      controlInfo.resumeCount += 1
    }

    // MARK: - Control Actions

    /// Pauses an active transfer
    /// - Parameter transferId: Transfer identifier to pause
    /// - Returns: Resume data if available
    public func pauseTransfer(
      _ transferId: TransferIdentifier
    ) async throws -> TransferResumeData? {
      guard let controlInfo = activeTransfers[transferId.rawValue] else {
        throw TransferControlError.transferNotFound(transferId)
      }

      guard controlInfo.state.canPause.rawValue else {
        throw TransferControlError.actionNotAllowed(.pause, currentState: controlInfo.state)
      }

      try await transitionToState(transferId: transferId, newState: .paused)

      return controlInfo.resumeData.map { TransferResumeData($0) }
    }

    /// Resumes a paused transfer
    /// - Parameters:
    ///   - transferId: Transfer identifier to resume
    ///   - resumeData: Optional resume data for continuation
    /// - Returns: Success status
    public func resumeTransfer(
      _ transferId: TransferIdentifier,
      resumeData: TransferResumeData? = nil
    ) async throws {
      guard var controlInfo = activeTransfers[transferId.rawValue] else {
        throw TransferControlError.transferNotFound(transferId)
      }

      guard controlInfo.state.canResume.rawValue else {
        throw TransferControlError.actionNotAllowed(.resume, currentState: controlInfo.state)
      }

      // Update resume data if provided
      if let resumeData = resumeData {
        controlInfo.resumeData = resumeData.rawValue
        activeTransfers[transferId.rawValue] = controlInfo
      }

      try await transitionToState(transferId: transferId, newState: .resuming)

      // LIFECYCLE: Fire-and-forget state transition - safe because:
      // 1. resuming→active transition is idempotent
      // 2. Actor isolation ensures thread safety
      // 3. Bounded delay (0.1s) followed by state mutation
      // 4. Failure to transition doesn't leak resources (state remains resuming)
      Task {
        _ = try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
        _ = try? await transitionToState(transferId: transferId, newState: .active)
      }
    }

    /// Cancels a transfer
    /// - Parameter transferId: Transfer identifier to cancel
    public func cancelTransfer(_ transferId: TransferIdentifier) async throws {
      guard let controlInfo = activeTransfers[transferId.rawValue] else {
        throw TransferControlError.transferNotFound(transferId)
      }

      guard controlInfo.state.canCancel.rawValue else {
        throw TransferControlError.actionNotAllowed(.cancel, currentState: controlInfo.state)
      }

      try await transitionToState(transferId: transferId, newState: .cancelling)

      // LIFECYCLE: Fire-and-forget cleanup - safe because:
      // 1. unregisterTransfer only removes dictionary entry
      // 2. Actor isolation ensures thread safety
      // 3. Bounded delay (0.5s) followed by single dictionary mutation
      // 4. Transfer already in terminal cancelling state, cleanup is just housekeeping
      Task {
        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 second
        await unregisterTransfer(transferId)
      }
    }

    /// Updates transfer priority
    /// - Parameters:
    ///   - transferId: Transfer identifier
    ///   - priority: New priority level
    public func updatePriority(
      _ transferId: TransferIdentifier,
      priority: TransferPriority
    ) async throws {
      guard var controlInfo = activeTransfers[transferId.rawValue] else {
        throw TransferControlError.transferNotFound(transferId)
      }

      controlInfo.priority = priority
      activeTransfers[transferId.rawValue] = controlInfo
    }

    /// Updates bandwidth limitation for a transfer
    /// - Parameters:
    ///   - transferId: Transfer identifier
    ///   - bandwidthLimit: New bandwidth limit
    public func updateBandwidthLimit(
      _ transferId: TransferIdentifier,
      bandwidthLimit: BandwidthLimit?
    ) async throws {
      guard var controlInfo = activeTransfers[transferId.rawValue] else {
        throw TransferControlError.transferNotFound(transferId)
      }

      // Validate bandwidth limit
      if let limit = bandwidthLimit, limit.bytesPerSecond.rawValue <= 0 {
        throw TransferControlError.invalidBandwidthLimit(limit.bytesPerSecond)
      }

      controlInfo.bandwidthLimit = bandwidthLimit
      activeTransfers[transferId.rawValue] = controlInfo
    }

    // MARK: - Batch Operations

    /// Pauses all active transfers
    /// - Returns: Dictionary of transfer IDs and their resume data
    public func pauseAllTransfers() async -> [TransferIdentifier: TransferResumeData?] {
      var resumeData: [TransferIdentifier: TransferResumeData?] = [:]

      for (transferId, controlInfo) in activeTransfers where controlInfo.state.canPause.rawValue {
        let wrappedTransferId = TransferIdentifier(transferId)
        do {
          let data = try await pauseTransfer(wrappedTransferId)
          resumeData[wrappedTransferId] = data
        } catch {
          resumeData[wrappedTransferId] = nil
        }
      }

      return resumeData
    }

    /// Resumes all paused transfers
    /// - Parameter resumeDataMap: Optional resume data for transfers
    public func resumeAllTransfers(
      resumeDataMap: [TransferIdentifier: TransferResumeData] = [:]
    ) async {
      for (transferId, controlInfo) in activeTransfers where controlInfo.state.canResume.rawValue {
        let wrappedTransferId = TransferIdentifier(transferId)
        let resumeData = resumeDataMap[wrappedTransferId]
        try? await resumeTransfer(wrappedTransferId, resumeData: resumeData)
      }
    }

    /// Cancels all active transfers
    public func cancelAllTransfers() async {
      for (transferId, controlInfo) in activeTransfers where controlInfo.state.canCancel.rawValue {
        try? await cancelTransfer(TransferIdentifier(transferId))
      }
    }

    // MARK: - Transfer Querying

    /// Gets all transfers with a specific state
    /// - Parameter state: State to filter by
    /// - Returns: Array of transfer IDs in that state
    public func getTransfers(withState state: TransferState) async -> [TransferIdentifier] {
      activeTransfers.compactMap { id, info in
        info.state == state ? TransferIdentifier(id) : nil
      }
    }

    /// Gets transfers ordered by priority
    /// - Returns: Transfer IDs ordered by priority (highest first)
    public func getTransfersByPriority() async -> [TransferIdentifier] {
      activeTransfers.sorted { first, second in
        first.value.priority.rank.rawValue > second.value.priority.rank.rawValue
      }.map { TransferIdentifier($0.key) }
    }

    /// Gets overall transfer statistics
    /// - Returns: Statistics about all managed transfers
    public func getTransferStatistics() async -> TransferStatistics {
      let transfers = Array(activeTransfers.values)

      let stateCount = Dictionary(grouping: transfers, by: \.state)
        .mapValues { TransferCount($0.count) }

      let priorityCount = Dictionary(grouping: transfers, by: \.priority)
        .mapValues { TransferCount($0.count) }

      return TransferStatistics(
        totalTransfers: TransferCount(transfers.count),
        activeTransfers: TransferCount(transfers.filter { $0.state.isActive.rawValue }.count),
        pausedTransfers: TransferCount(transfers.filter { $0.state == .paused }.count),
        completedTransfers: TransferCount(transfers.filter { $0.state == .completed }.count),
        failedTransfers: TransferCount(transfers.filter { $0.state == .failed }.count),
        stateDistribution: stateCount,
        priorityDistribution: priorityCount,
        averageActiveDuration: TransferDuration(
          transfers.map(\.activeDuration).reduce(0, +) / max(Double(transfers.count), 1)
        )
      )
    }
  }

  // MARK: - Transfer Priority

  /// Priority levels for transfer operations
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

  // MARK: - Bandwidth Management

  /// Bandwidth limitation configuration
  public struct BandwidthLimit: Sendable, Hashable {
    /// Maximum bytes per second
    public let bytesPerSecond: TransferByteRate

    /// Whether the limit applies to upload, download, or both
    public let direction: Direction

    /// Time window for rate calculation (in seconds)
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

    /// Convenience initializer for MB/s
    public static func megabytesPerSecond(
      _ mbps: TransferSpeed,
      direction: Direction = .both
    ) -> Self {
      Self(bytesPerSecond: TransferByteRate(mbps.rawValue * 1_048_576), direction: direction)
    }

    /// Convenience initializer for KB/s
    public static func kilobytesPerSecond(
      _ kbps: TransferSpeed,
      direction: Direction = .both
    ) -> Self {
      Self(bytesPerSecond: TransferByteRate(kbps.rawValue * 1024), direction: direction)
    }

    /// Human-readable description
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

  /// Actor that enforces bandwidth limits across transfers
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
        if windowDuration >= 1.0 {  // 1-second window
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

    /// Sets bandwidth limit for a specific transfer
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

    /// Checks if a transfer can send/receive bytes without exceeding limits
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

    /// Records bandwidth usage for a transfer
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

    /// Removes transfer from bandwidth tracking
    /// - Parameter transferId: Transfer identifier
    public func removeTransfer(_ transferId: TransferIdentifier) {
      transferLimits.removeValue(forKey: transferId.rawValue)
      transferUsage.removeValue(forKey: transferId.rawValue)
    }
  }

  // MARK: - Supporting Types

  /// Configuration for transfer control manager
  public struct TransferControlConfiguration: Sendable {
    /// Maximum number of concurrent active transfers
    public let maxConcurrentTransfers: TransferConcurrencyLimit

    /// Default bandwidth limit applied to all transfers
    public let defaultBandwidthLimit: BandwidthLimit?

    /// Automatic retry configuration for failed transfers
    public let autoRetryConfiguration: AutoRetryConfiguration?

    /// Whether to automatically manage transfer priorities based on system load
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

  /// Configuration for automatic retry behavior
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

  /// Public transfer information
  public struct TransferInfo: Sendable {
    public let transferId: TransferIdentifier
    public let state: TransferState
    public let priority: TransferPriority
    public let bandwidthLimit: BandwidthLimit?
    public let totalDuration: TransferDuration
    public let activeDuration: TransferDuration
    public let pauseCount: TransferPauseCount
    public let resumeCount: TransferResumeCount

    /// Efficiency ratio (active time / total time)
    public var efficiency: TransferEfficiencyValue {
      guard totalDuration.rawValue > 0 else { return 0 }
      return TransferEfficiencyValue(activeDuration.rawValue / totalDuration.rawValue)
    }
  }

  /// Statistics about all managed transfers
  public struct TransferStatistics: Sendable {
    public let totalTransfers: TransferCount
    public let activeTransfers: TransferCount
    public let pausedTransfers: TransferCount
    public let completedTransfers: TransferCount
    public let failedTransfers: TransferCount
    public let stateDistribution: [TransferState: TransferCount]
    public let priorityDistribution: [TransferPriority: TransferCount]
    public let averageActiveDuration: TransferDuration

    /// Success rate percentage
    public var successRate: TransferSuccessRate {
      let totalFinished = completedTransfers.rawValue + failedTransfers.rawValue
      guard totalFinished > 0 else { return 0 }
      return TransferSuccessRate(Double(completedTransfers.rawValue) / Double(totalFinished) * 100)
    }
  }
}

// MARK: - Extensions

extension TransferControls.TransferState: CustomStringConvertible {
  public var description: String {
    switch self {
    case .waiting: return "Waiting"
    case .preparing: return "Preparing"
    case .active: return "Active"
    case .paused: return "Paused"
    case .resuming: return "Resuming"
    case .cancelling: return "Cancelling"
    case .cancelled: return "Cancelled"
    case .completed: return "Completed"
    case .failed: return "Failed"
    }
  }
}

extension TransferControls.BandwidthLimit: CustomStringConvertible {}

// MARK: - Convenience Extensions

extension TransferControls.TransferControlManager {
  /// Creates a manager with production-ready configuration
  public static func production(
    maxConcurrentTransfers: TransferConcurrencyLimit = 8
  ) -> TransferControls.TransferControlManager {
    let config = TransferControls.TransferControlConfiguration(
      maxConcurrentTransfers: maxConcurrentTransfers,
      defaultBandwidthLimit: nil,
      autoRetryConfiguration: TransferControls.AutoRetryConfiguration(),
      enableAdaptivePriority: true
    )
    return TransferControls.TransferControlManager(configuration: config)
  }

  /// Creates a manager with conservative resource usage
  public static func conservative() -> TransferControls.TransferControlManager {
    let config = TransferControls.TransferControlConfiguration(
      maxConcurrentTransfers: 2,
      defaultBandwidthLimit: .kilobytesPerSecond(512),  // 512 KB/s
      enableAdaptivePriority: false
    )
    return TransferControls.TransferControlManager(configuration: config)
  }
}
