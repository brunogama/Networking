import Foundation

/// Advanced transfer control system providing pause/resume functionality,
/// state management, and bandwidth throttling capabilities.
public struct TransferControls: Sendable {
  // MARK: - Transfer State Management

  /// Transfer states that control the flow and behavior of active transfers
  public enum TransferState: String, Sendable, CaseIterable, Hashable {
    case waiting = "waiting"
    case preparing = "preparing"
    case active = "active"
    case paused = "paused"
    case resuming = "resuming"
    case cancelling = "cancelling"
    case cancelled = "cancelled"
    case completed = "completed"
    case failed = "failed"

    /// Whether the transfer is currently processing data
    public var isActive: Bool {
      switch self {
      case .active, .resuming:
        return true

      case .waiting, .preparing, .paused, .cancelling, .cancelled, .completed, .failed:
        return false
      }
    }

    /// Whether the transfer can be paused
    public var canPause: Bool {
      switch self {
      case .active, .resuming:
        return true

      case .waiting, .preparing, .paused, .cancelling, .cancelled, .completed, .failed:
        return false
      }
    }

    /// Whether the transfer can be resumed
    public var canResume: Bool {
      switch self {
      case .paused:
        return true

      case .waiting, .preparing, .active, .resuming, .cancelling, .cancelled, .completed, .failed:
        return false
      }
    }

    /// Whether the transfer can be cancelled
    public var canCancel: Bool {
      switch self {
      case .waiting, .preparing, .active, .paused, .resuming:
        return true

      case .cancelling, .cancelled, .completed, .failed:
        return false
      }
    }
  }

  /// Transfer control actions that can be performed
  public enum ControlAction: String, Sendable, CaseIterable {
    case pause = "pause"
    case resume = "resume"
    case cancel = "cancel"
    case restart = "restart"
    case prioritize = "prioritize"
    case throttle = "throttle"
  }

  /// Errors that can occur during transfer control operations
  public enum TransferControlError: Error, LocalizedError {
    case invalidStateTransition(from: TransferState, to: TransferState)
    case transferNotFound(UUID)
    case actionNotAllowed(ControlAction, currentState: TransferState)
    case invalidBandwidthLimit(Double)
    case resumeDataCorrupted
    case concurrencyLimitExceeded(limit: Int)

    public var errorDescription: String? {
      switch self {
      case .invalidStateTransition(let from, let to):
        return "Invalid state transition from \(from.rawValue) to \(to.rawValue)"

      case .transferNotFound(let id):
        return "Transfer with ID \(id) not found"

      case .actionNotAllowed(let action, let state):
        return "Action '\(action.rawValue)' not allowed in state '\(state.rawValue)'"

      case .invalidBandwidthLimit(let limit):
        return "Invalid bandwidth limit: \(limit) bytes/sec"

      case .resumeDataCorrupted:
        return "Resume data is corrupted and cannot be used"

      case .concurrencyLimitExceeded(let limit):
        return "Concurrency limit of \(limit) transfers exceeded"
      }
    }
  }

  // MARK: - Transfer Control Manager

  /// Actor-based manager that handles transfer state and control operations
  public actor TransferControlManager {
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
        let currentPausedTime =
          state == .paused && pauseTime != nil ? Date().timeIntervalSince(pauseTime!) : 0
        return totalDuration - totalPausedDuration - currentPausedTime
      }
    }

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
      _ transferId: UUID,
      priority: TransferPriority = .normal,
      bandwidthLimit: BandwidthLimit? = nil
    ) async throws -> TransferState {
      // Check concurrency limits
      let activeCount = activeTransfers.values.filter { $0.state.isActive }.count
      if activeCount >= configuration.maxConcurrentTransfers {
        throw TransferControlError.concurrencyLimitExceeded(
          limit: configuration.maxConcurrentTransfers
        )
      }

      let controlInfo = TransferControlInfo(
        transferId: transferId,
        state: .waiting,
        priority: priority,
        bandwidthLimit: bandwidthLimit
      )

      activeTransfers[transferId] = controlInfo

      // Start the transfer if conditions allow
      return try await transitionToState(transferId: transferId, newState: .preparing)
    }

    /// Unregisters a transfer from the control manager
    /// - Parameter transferId: Transfer identifier to remove
    public func unregisterTransfer(_ transferId: UUID) async {
      activeTransfers.removeValue(forKey: transferId)
    }

    // MARK: - State Management

    /// Gets the current state of a transfer
    /// - Parameter transferId: Transfer identifier
    /// - Returns: Current transfer state, or nil if transfer not found
    public func getTransferState(_ transferId: UUID) async -> TransferState? {
      activeTransfers[transferId]?.state
    }

    /// Gets comprehensive transfer information
    /// - Parameter transferId: Transfer identifier
    /// - Returns: Transfer info or nil if not found
    public func getTransferInfo(_ transferId: UUID) async -> TransferInfo? {
      guard let controlInfo = activeTransfers[transferId] else { return nil }

      return TransferInfo(
        transferId: transferId,
        state: controlInfo.state,
        priority: controlInfo.priority,
        bandwidthLimit: controlInfo.bandwidthLimit,
        totalDuration: controlInfo.totalDuration,
        activeDuration: controlInfo.activeDuration,
        pauseCount: controlInfo.pauseCount,
        resumeCount: controlInfo.resumeCount
      )
    }

    /// Transitions a transfer to a new state
    /// - Parameters:
    ///   - transferId: Transfer identifier
    ///   - newState: Target state
    /// - Returns: The new state if successful
    @discardableResult
    public func transitionToState(
      transferId: UUID,
      newState: TransferState
    ) async throws -> TransferState {
      guard var controlInfo = activeTransfers[transferId] else {
        throw TransferControlError.transferNotFound(transferId)
      }

      // Validate state transition
      guard isValidStateTransition(from: controlInfo.state, to: newState) else {
        throw TransferControlError.invalidStateTransition(from: controlInfo.state, to: newState)
      }

      // Handle special state transitions
      switch (controlInfo.state, newState) {
      case (.active, .paused), (.resuming, .paused):
        controlInfo.pauseTime = Date()
        controlInfo.pauseCount += 1

      case (.paused, .resuming), (.paused, .active):
        if let pauseTime = controlInfo.pauseTime {
          controlInfo.totalPausedDuration += Date().timeIntervalSince(pauseTime)
        }
        controlInfo.pauseTime = nil
        controlInfo.resumeCount += 1

      default:
        break
      }

      controlInfo.state = newState
      controlInfo.lastStateChangeTime = Date()
      activeTransfers[transferId] = controlInfo

      return newState
    }

    private func isValidStateTransition(from: TransferState, to: TransferState) -> Bool {
      switch (from, to) {
      // Valid transitions from waiting
      case (.waiting, .preparing), (.waiting, .cancelled):
        return true

      // Valid transitions from preparing
      case (.preparing, .active), (.preparing, .paused), (.preparing, .cancelled):
        return true

      // Valid transitions from active
      case (.active, .paused), (.active, .cancelling), (.active, .completed), (.active, .failed):
        return true

      // Valid transitions from paused
      case (.paused, .resuming), (.paused, .cancelling):
        return true

      // Valid transitions from resuming
      case (.resuming, .active), (.resuming, .paused), (.resuming, .failed):
        return true

      // Valid transitions from cancelling
      case (.cancelling, .cancelled):
        return true

      // Terminal states
      case (.completed, _), (.failed, _), (.cancelled, _):
        return false

      default:
        return false
      }
    }

    // MARK: - Control Actions

    /// Pauses an active transfer
    /// - Parameter transferId: Transfer identifier to pause
    /// - Returns: Resume data if available
    public func pauseTransfer(_ transferId: UUID) async throws -> Data? {
      guard let controlInfo = activeTransfers[transferId] else {
        throw TransferControlError.transferNotFound(transferId)
      }

      guard controlInfo.state.canPause else {
        throw TransferControlError.actionNotAllowed(.pause, currentState: controlInfo.state)
      }

      try await transitionToState(transferId: transferId, newState: .paused)

      return controlInfo.resumeData
    }

    /// Resumes a paused transfer
    /// - Parameters:
    ///   - transferId: Transfer identifier to resume
    ///   - resumeData: Optional resume data for continuation
    /// - Returns: Success status
    public func resumeTransfer(_ transferId: UUID, resumeData: Data? = nil) async throws {
      guard var controlInfo = activeTransfers[transferId] else {
        throw TransferControlError.transferNotFound(transferId)
      }

      guard controlInfo.state.canResume else {
        throw TransferControlError.actionNotAllowed(.resume, currentState: controlInfo.state)
      }

      // Update resume data if provided
      if let resumeData = resumeData {
        controlInfo.resumeData = resumeData
        activeTransfers[transferId] = controlInfo
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
    public func cancelTransfer(_ transferId: UUID) async throws {
      guard let controlInfo = activeTransfers[transferId] else {
        throw TransferControlError.transferNotFound(transferId)
      }

      guard controlInfo.state.canCancel else {
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
    public func updatePriority(_ transferId: UUID, priority: TransferPriority) async throws {
      guard var controlInfo = activeTransfers[transferId] else {
        throw TransferControlError.transferNotFound(transferId)
      }

      controlInfo.priority = priority
      activeTransfers[transferId] = controlInfo
    }

    /// Updates bandwidth limitation for a transfer
    /// - Parameters:
    ///   - transferId: Transfer identifier
    ///   - bandwidthLimit: New bandwidth limit
    public func updateBandwidthLimit(
      _ transferId: UUID,
      bandwidthLimit: BandwidthLimit?
    ) async throws {
      guard var controlInfo = activeTransfers[transferId] else {
        throw TransferControlError.transferNotFound(transferId)
      }

      // Validate bandwidth limit
      if let limit = bandwidthLimit, limit.bytesPerSecond <= 0 {
        throw TransferControlError.invalidBandwidthLimit(limit.bytesPerSecond)
      }

      controlInfo.bandwidthLimit = bandwidthLimit
      activeTransfers[transferId] = controlInfo
    }

    // MARK: - Batch Operations

    /// Pauses all active transfers
    /// - Returns: Dictionary of transfer IDs and their resume data
    public func pauseAllTransfers() async -> [UUID: Data?] {
      var resumeData: [UUID: Data?] = [:]

      for (transferId, controlInfo) in activeTransfers {
        if controlInfo.state.canPause {
          do {
            let data = try await pauseTransfer(transferId)
            resumeData[transferId] = data
          } catch {
            resumeData[transferId] = nil
          }
        }
      }

      return resumeData
    }

    /// Resumes all paused transfers
    /// - Parameter resumeDataMap: Optional resume data for transfers
    public func resumeAllTransfers(resumeDataMap: [UUID: Data] = [:]) async {
      for (transferId, controlInfo) in activeTransfers {
        if controlInfo.state.canResume {
          let resumeData = resumeDataMap[transferId]
          try? await resumeTransfer(transferId, resumeData: resumeData)
        }
      }
    }

    /// Cancels all active transfers
    public func cancelAllTransfers() async {
      for (transferId, controlInfo) in activeTransfers {
        if controlInfo.state.canCancel {
          try? await cancelTransfer(transferId)
        }
      }
    }

    // MARK: - Transfer Querying

    /// Gets all transfers with a specific state
    /// - Parameter state: State to filter by
    /// - Returns: Array of transfer IDs in that state
    public func getTransfers(withState state: TransferState) async -> [UUID] {
      activeTransfers.compactMap { id, info in
        info.state == state ? id : nil
      }
    }

    /// Gets transfers ordered by priority
    /// - Returns: Transfer IDs ordered by priority (highest first)
    public func getTransfersByPriority() async -> [UUID] {
      activeTransfers.sorted { first, second in
        first.value.priority.rawValue > second.value.priority.rawValue
      }.map { $0.key }
    }

    /// Gets overall transfer statistics
    /// - Returns: Statistics about all managed transfers
    public func getTransferStatistics() async -> TransferStatistics {
      let transfers = Array(activeTransfers.values)

      let stateCount = Dictionary(grouping: transfers, by: \.state)
        .mapValues { $0.count }

      let priorityCount = Dictionary(grouping: transfers, by: \.priority)
        .mapValues { $0.count }

      return TransferStatistics(
        totalTransfers: transfers.count,
        activeTransfers: transfers.filter { $0.state.isActive }.count,
        pausedTransfers: transfers.filter { $0.state == .paused }.count,
        completedTransfers: transfers.filter { $0.state == .completed }.count,
        failedTransfers: transfers.filter { $0.state == .failed }.count,
        stateDistribution: stateCount,
        priorityDistribution: priorityCount,
        averageActiveDuration: transfers.map(\.activeDuration).reduce(0, +)
          / max(Double(transfers.count), 1)
      )
    }
  }

  // MARK: - Transfer Priority

  /// Priority levels for transfer operations
  public enum TransferPriority: Int, Sendable, CaseIterable, Comparable {
    case background = 0
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4

    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.rawValue < rhs.rawValue
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
    public let bytesPerSecond: Double

    /// Whether the limit applies to upload, download, or both
    public let direction: Direction

    /// Time window for rate calculation (in seconds)
    public let timeWindow: TimeInterval

    public enum Direction: String, Sendable, CaseIterable {
      case upload = "upload"
      case download = "download"
      case both = "both"
    }

    public init(
      bytesPerSecond: Double,
      direction: Direction = .both,
      timeWindow: TimeInterval = 1.0
    ) {
      self.bytesPerSecond = bytesPerSecond
      self.direction = direction
      self.timeWindow = timeWindow
    }

    /// Convenience initializer for MB/s
    public static func megabytesPerSecond(
      _ mbps: Double,
      direction: Direction = .both
    ) -> Self {
      Self(bytesPerSecond: mbps * 1_048_576, direction: direction)
    }

    /// Convenience initializer for KB/s
    public static func kilobytesPerSecond(
      _ kbps: Double,
      direction: Direction = .both
    ) -> Self {
      Self(bytesPerSecond: kbps * 1024, direction: direction)
    }

    /// Human-readable description
    public var description: String {
      let speed: String
      if bytesPerSecond >= 1_048_576 {
        speed = String(format: "%.1f MB/s", bytesPerSecond / 1_048_576)
      } else if bytesPerSecond >= 1024 {
        speed = String(format: "%.1f KB/s", bytesPerSecond / 1024)
      } else {
        speed = String(format: "%.0f B/s", bytesPerSecond)
      }
      return "\(speed) (\(direction.rawValue))"
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
    public func setBandwidthLimit(for transferId: UUID, limit: BandwidthLimit?) {
      if let limit = limit {
        transferLimits[transferId] = limit
        if transferUsage[transferId] == nil {
          transferUsage[transferId] = BandwidthUsage()
        }
      } else {
        transferLimits.removeValue(forKey: transferId)
        transferUsage.removeValue(forKey: transferId)
      }
    }

    /// Checks if a transfer can send/receive bytes without exceeding limits
    /// - Parameters:
    ///   - transferId: Transfer identifier
    ///   - bytes: Number of bytes to transfer
    ///   - direction: Transfer direction
    /// - Returns: Whether the transfer is allowed and suggested delay
    public func checkBandwidthLimit(
      for transferId: UUID,
      bytes: Double,
      direction: BandwidthLimit.Direction
    ) -> (allowed: Bool, suggestedDelay: TimeInterval) {
      // Check transfer-specific limit
      if let limit = transferLimits[transferId],
        let usage = transferUsage[transferId]
      {
        // Skip if direction doesn't match
        if limit.direction != .both && limit.direction != direction {
          return (true, 0)
        }

        let currentRate = usage.currentRate()
        if currentRate + (bytes / limit.timeWindow) > limit.bytesPerSecond {
          let excessRate = (currentRate + (bytes / limit.timeWindow)) - limit.bytesPerSecond
          let delay = excessRate / limit.bytesPerSecond * limit.timeWindow
          return (false, delay)
        }
      }

      // Check global limit
      if let globalLimit = globalLimit {
        if globalLimit.direction == .both || globalLimit.direction == direction {
          let totalRate = transferUsage.values.reduce(0) { $0 + $1.currentRate() }
          if totalRate + (bytes / globalLimit.timeWindow) > globalLimit.bytesPerSecond {
            let excessRate =
              (totalRate + (bytes / globalLimit.timeWindow)) - globalLimit.bytesPerSecond
            let delay = excessRate / globalLimit.bytesPerSecond * globalLimit.timeWindow
            return (false, delay)
          }
        }
      }

      return (true, 0)
    }

    /// Records bandwidth usage for a transfer
    /// - Parameters:
    ///   - transferId: Transfer identifier
    ///   - bytes: Bytes transferred
    public func recordBandwidthUsage(for transferId: UUID, bytes: Double) {
      if transferUsage[transferId] != nil {
        transferUsage[transferId]?.addBytes(bytes)
      } else if transferLimits[transferId] != nil {
        var usage = BandwidthUsage()
        usage.addBytes(bytes)
        transferUsage[transferId] = usage
      }
    }

    /// Removes transfer from bandwidth tracking
    /// - Parameter transferId: Transfer identifier
    public func removeTransfer(_ transferId: UUID) {
      transferLimits.removeValue(forKey: transferId)
      transferUsage.removeValue(forKey: transferId)
    }
  }

  // MARK: - Supporting Types

  /// Configuration for transfer control manager
  public struct TransferControlConfiguration: Sendable {
    /// Maximum number of concurrent active transfers
    public let maxConcurrentTransfers: Int

    /// Default bandwidth limit applied to all transfers
    public let defaultBandwidthLimit: BandwidthLimit?

    /// Automatic retry configuration for failed transfers
    public let autoRetryConfiguration: AutoRetryConfiguration?

    /// Whether to automatically manage transfer priorities based on system load
    public let enableAdaptivePriority: Bool

    public init(
      maxConcurrentTransfers: Int = 4,
      defaultBandwidthLimit: BandwidthLimit? = nil,
      autoRetryConfiguration: AutoRetryConfiguration? = nil,
      enableAdaptivePriority: Bool = false
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
    public let maxRetries: Int
    public let baseDelay: TimeInterval
    public let backoffMultiplier: Double
    public let maxDelay: TimeInterval

    public init(
      maxRetries: Int = 3,
      baseDelay: TimeInterval = 1.0,
      backoffMultiplier: Double = 2.0,
      maxDelay: TimeInterval = 60.0
    ) {
      self.maxRetries = maxRetries
      self.baseDelay = baseDelay
      self.backoffMultiplier = backoffMultiplier
      self.maxDelay = maxDelay
    }
  }

  /// Public transfer information
  public struct TransferInfo: Sendable {
    public let transferId: UUID
    public let state: TransferState
    public let priority: TransferPriority
    public let bandwidthLimit: BandwidthLimit?
    public let totalDuration: TimeInterval
    public let activeDuration: TimeInterval
    public let pauseCount: Int
    public let resumeCount: Int

    /// Efficiency ratio (active time / total time)
    public var efficiency: Double {
      guard totalDuration > 0 else { return 0 }
      return activeDuration / totalDuration
    }
  }

  /// Statistics about all managed transfers
  public struct TransferStatistics: Sendable {
    public let totalTransfers: Int
    public let activeTransfers: Int
    public let pausedTransfers: Int
    public let completedTransfers: Int
    public let failedTransfers: Int
    public let stateDistribution: [TransferState: Int]
    public let priorityDistribution: [TransferPriority: Int]
    public let averageActiveDuration: TimeInterval

    /// Success rate percentage
    public var successRate: Double {
      let totalFinished = completedTransfers + failedTransfers
      guard totalFinished > 0 else { return 0 }
      return Double(completedTransfers) / Double(totalFinished) * 100
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
    maxConcurrentTransfers: Int = 8
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
