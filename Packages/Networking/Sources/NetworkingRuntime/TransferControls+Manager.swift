// swiftlint:disable file_length
import Foundation
import NetworkingCore

extension TransferControls {
  /// Actor-based manager that handles transfer state and control operations.
  public actor TransferControlManager {  // swiftlint:disable:this type_body_length
    /// Information about an active transfer and its control state.
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

      /// Total time since transfer was created.
      var totalDuration: TimeInterval {
        Date().timeIntervalSince(creationTime)
      }

      /// Active duration (excluding paused time).
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

    /// Registers a new transfer with the control manager.
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
      return try await transitionToState(transferId: transferId, newState: .preparing)
    }

    /// Unregisters a transfer from the control manager.
    /// - Parameter transferId: Transfer identifier to remove
    public func unregisterTransfer(_ transferId: TransferIdentifier) async {
      activeTransfers.removeValue(forKey: transferId.rawValue)
    }

    // MARK: - State Management

    /// Gets the current state of a transfer.
    /// - Parameter transferId: Transfer identifier
    /// - Returns: Current transfer state, or nil if transfer not found
    public func getTransferState(_ transferId: TransferIdentifier) async -> TransferState? {
      activeTransfers[transferId.rawValue]?.state
    }

    /// Gets comprehensive transfer information.
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

    /// Transitions a transfer to a new state.
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

      guard isValidStateTransition(from: controlInfo.state, to: newState) else {
        throw TransferControlError.invalidStateTransition(from: controlInfo.state, to: newState)
      }

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

    /// Pauses an active transfer.
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

    /// Resumes a paused transfer.
    /// - Parameters:
    ///   - transferId: Transfer identifier to resume
    ///   - resumeData: Optional resume data for continuation
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

      if let resumeData = resumeData {
        controlInfo.resumeData = resumeData.rawValue
        activeTransfers[transferId.rawValue] = controlInfo
      }

      try await transitionToState(transferId: transferId, newState: .resuming)

      Task {
        _ = try? await Task.sleep(nanoseconds: 100_000_000)
        _ = try? await transitionToState(transferId: transferId, newState: .active)
      }
    }

    /// Cancels a transfer.
    /// - Parameter transferId: Transfer identifier to cancel
    public func cancelTransfer(_ transferId: TransferIdentifier) async throws {
      guard let controlInfo = activeTransfers[transferId.rawValue] else {
        throw TransferControlError.transferNotFound(transferId)
      }

      guard controlInfo.state.canCancel.rawValue else {
        throw TransferControlError.actionNotAllowed(.cancel, currentState: controlInfo.state)
      }

      try await transitionToState(transferId: transferId, newState: .cancelling)

      Task {
        try? await Task.sleep(nanoseconds: 500_000_000)
        await unregisterTransfer(transferId)
      }
    }

    /// Updates transfer priority.
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

    /// Updates bandwidth limitation for a transfer.
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

      if let limit = bandwidthLimit, limit.bytesPerSecond.rawValue <= 0 {
        throw TransferControlError.invalidBandwidthLimit(limit.bytesPerSecond)
      }

      controlInfo.bandwidthLimit = bandwidthLimit
      activeTransfers[transferId.rawValue] = controlInfo
    }

    // MARK: - Batch Operations

    /// Pauses all active transfers.
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

    /// Resumes all paused transfers.
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

    /// Cancels all active transfers.
    public func cancelAllTransfers() async {
      for (transferId, controlInfo) in activeTransfers where controlInfo.state.canCancel.rawValue {
        try? await cancelTransfer(TransferIdentifier(transferId))
      }
    }

    // MARK: - Transfer Querying

    /// Gets all transfers with a specific state.
    /// - Parameter state: State to filter by
    /// - Returns: Array of transfer IDs in that state
    public func getTransfers(withState state: TransferState) async -> [TransferIdentifier] {
      activeTransfers.compactMap { id, info in
        info.state == state ? TransferIdentifier(id) : nil
      }
    }

    /// Gets transfers ordered by priority.
    /// - Returns: Transfer IDs ordered by priority (highest first)
    public func getTransfersByPriority() async -> [TransferIdentifier] {
      activeTransfers.sorted { first, second in
        first.value.priority.rank.rawValue > second.value.priority.rank.rawValue
      }.map { TransferIdentifier($0.key) }
    }

    /// Gets overall transfer statistics.
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
}

extension TransferControls.TransferControlManager {
  /// Creates a manager with production-ready configuration.
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

  /// Creates a manager with conservative resource usage.
  public static func conservative() -> TransferControls.TransferControlManager {
    let config = TransferControls.TransferControlConfiguration(
      maxConcurrentTransfers: 2,
      defaultBandwidthLimit: .kilobytesPerSecond(512),
      enableAdaptivePriority: false
    )
    return TransferControls.TransferControlManager(configuration: config)
  }
}
