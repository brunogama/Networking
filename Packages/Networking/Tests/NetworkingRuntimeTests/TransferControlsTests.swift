// swiftlint:disable file_length
import Foundation
import XCTest

@testable import NetworkingRuntime
import NetworkingDSL
import NetworkingRuntimeDSL
import NetworkingTesting

// Comprehensive tests for TransferControls state management and transfer operations.
// swiftlint:disable:next type_body_length
final class TransferControlsTests: XCTestCase {
  // MARK: - TransferState Tests

  func testTransferStateAllCases() {
    let allStates = TransferControls.TransferState.allCases

    XCTAssertEqual(allStates.count, 9)
    XCTAssertTrue(allStates.contains(.waiting))
    XCTAssertTrue(allStates.contains(.preparing))
    XCTAssertTrue(allStates.contains(.active))
    XCTAssertTrue(allStates.contains(.paused))
    XCTAssertTrue(allStates.contains(.resuming))
    XCTAssertTrue(allStates.contains(.cancelling))
    XCTAssertTrue(allStates.contains(.cancelled))
    XCTAssertTrue(allStates.contains(.completed))
    XCTAssertTrue(allStates.contains(.failed))
  }

  func testTransferStateRawValues() {
    XCTAssertEqual(TransferControls.TransferState.waiting.identifier.rawValue, "waiting")
    XCTAssertEqual(TransferControls.TransferState.preparing.identifier.rawValue, "preparing")
    XCTAssertEqual(TransferControls.TransferState.active.identifier.rawValue, "active")
    XCTAssertEqual(TransferControls.TransferState.paused.identifier.rawValue, "paused")
    XCTAssertEqual(TransferControls.TransferState.resuming.identifier.rawValue, "resuming")
    XCTAssertEqual(TransferControls.TransferState.cancelling.identifier.rawValue, "cancelling")
    XCTAssertEqual(TransferControls.TransferState.cancelled.identifier.rawValue, "cancelled")
    XCTAssertEqual(TransferControls.TransferState.completed.identifier.rawValue, "completed")
    XCTAssertEqual(TransferControls.TransferState.failed.identifier.rawValue, "failed")
  }

  func testTransferStateIsActive() {
    XCTAssertTrue(TransferControls.TransferState.active.isActive.rawValue)
    XCTAssertTrue(TransferControls.TransferState.resuming.isActive.rawValue)

    XCTAssertFalse(TransferControls.TransferState.waiting.isActive.rawValue)
    XCTAssertFalse(TransferControls.TransferState.preparing.isActive.rawValue)
    XCTAssertFalse(TransferControls.TransferState.paused.isActive.rawValue)
    XCTAssertFalse(TransferControls.TransferState.cancelling.isActive.rawValue)
    XCTAssertFalse(TransferControls.TransferState.cancelled.isActive.rawValue)
    XCTAssertFalse(TransferControls.TransferState.completed.isActive.rawValue)
    XCTAssertFalse(TransferControls.TransferState.failed.isActive.rawValue)
  }

  func testTransferStateCanPause() {
    XCTAssertTrue(TransferControls.TransferState.active.canPause.rawValue)
    XCTAssertTrue(TransferControls.TransferState.resuming.canPause.rawValue)

    XCTAssertFalse(TransferControls.TransferState.waiting.canPause.rawValue)
    XCTAssertFalse(TransferControls.TransferState.preparing.canPause.rawValue)
    XCTAssertFalse(TransferControls.TransferState.paused.canPause.rawValue)
    XCTAssertFalse(TransferControls.TransferState.cancelling.canPause.rawValue)
    XCTAssertFalse(TransferControls.TransferState.cancelled.canPause.rawValue)
    XCTAssertFalse(TransferControls.TransferState.completed.canPause.rawValue)
    XCTAssertFalse(TransferControls.TransferState.failed.canPause.rawValue)
  }

  func testTransferStateCanResume() {
    XCTAssertTrue(TransferControls.TransferState.paused.canResume.rawValue)

    XCTAssertFalse(TransferControls.TransferState.waiting.canResume.rawValue)
    XCTAssertFalse(TransferControls.TransferState.preparing.canResume.rawValue)
    XCTAssertFalse(TransferControls.TransferState.active.canResume.rawValue)
    XCTAssertFalse(TransferControls.TransferState.resuming.canResume.rawValue)
    XCTAssertFalse(TransferControls.TransferState.cancelling.canResume.rawValue)
    XCTAssertFalse(TransferControls.TransferState.cancelled.canResume.rawValue)
    XCTAssertFalse(TransferControls.TransferState.completed.canResume.rawValue)
    XCTAssertFalse(TransferControls.TransferState.failed.canResume.rawValue)
  }

  func testTransferStateCanCancel() {
    XCTAssertTrue(TransferControls.TransferState.waiting.canCancel.rawValue)
    XCTAssertTrue(TransferControls.TransferState.preparing.canCancel.rawValue)
    XCTAssertTrue(TransferControls.TransferState.active.canCancel.rawValue)
    XCTAssertTrue(TransferControls.TransferState.paused.canCancel.rawValue)
    XCTAssertTrue(TransferControls.TransferState.resuming.canCancel.rawValue)

    XCTAssertFalse(TransferControls.TransferState.cancelling.canCancel.rawValue)
    XCTAssertFalse(TransferControls.TransferState.cancelled.canCancel.rawValue)
    XCTAssertFalse(TransferControls.TransferState.completed.canCancel.rawValue)
    XCTAssertFalse(TransferControls.TransferState.failed.canCancel.rawValue)
  }

  func testTransferStateDescription() {
    XCTAssertEqual(TransferControls.TransferState.waiting.description, "Waiting")
    XCTAssertEqual(TransferControls.TransferState.preparing.description, "Preparing")
    XCTAssertEqual(TransferControls.TransferState.active.description, "Active")
    XCTAssertEqual(TransferControls.TransferState.paused.description, "Paused")
    XCTAssertEqual(TransferControls.TransferState.resuming.description, "Resuming")
    XCTAssertEqual(TransferControls.TransferState.cancelling.description, "Cancelling")
    XCTAssertEqual(TransferControls.TransferState.cancelled.description, "Cancelled")
    XCTAssertEqual(TransferControls.TransferState.completed.description, "Completed")
    XCTAssertEqual(TransferControls.TransferState.failed.description, "Failed")
  }

  func testTransferStateHashable() {
    var set: Set<TransferControls.TransferState> = []
    set.insert(.active)
    set.insert(.paused)
    set.insert(.active)

    XCTAssertEqual(set.count, 2)
  }

  // MARK: - ControlAction Tests

  func testControlActionAllCases() {
    let allActions = TransferControls.ControlAction.allCases

    XCTAssertEqual(allActions.count, 6)
    XCTAssertTrue(allActions.contains(.pause))
    XCTAssertTrue(allActions.contains(.resume))
    XCTAssertTrue(allActions.contains(.cancel))
    XCTAssertTrue(allActions.contains(.restart))
    XCTAssertTrue(allActions.contains(.prioritize))
    XCTAssertTrue(allActions.contains(.throttle))
  }

  func testControlActionRawValues() {
    XCTAssertEqual(TransferControls.ControlAction.pause.identifier.rawValue, "pause")
    XCTAssertEqual(TransferControls.ControlAction.resume.identifier.rawValue, "resume")
    XCTAssertEqual(TransferControls.ControlAction.cancel.identifier.rawValue, "cancel")
    XCTAssertEqual(TransferControls.ControlAction.restart.identifier.rawValue, "restart")
    XCTAssertEqual(TransferControls.ControlAction.prioritize.identifier.rawValue, "prioritize")
    XCTAssertEqual(TransferControls.ControlAction.throttle.identifier.rawValue, "throttle")
  }

  // MARK: - TransferControlError Tests

  func testTransferControlErrorInvalidStateTransition() {
    let error = TransferControls.TransferControlError.invalidStateTransition(
      from: .waiting,
      to: .completed
    )

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("waiting") ?? false)
    XCTAssertTrue(error.errorDescription?.contains("completed") ?? false)
  }

  func testTransferControlErrorTransferNotFound() {
    let id = TransferIdentifier()
    let error = TransferControls.TransferControlError.transferNotFound(id)

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains(id.rawValue.uuidString) ?? false)
  }

  func testTransferControlErrorActionNotAllowed() {
    let error = TransferControls.TransferControlError.actionNotAllowed(
      .pause,
      currentState: .completed
    )

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("pause") ?? false)
    XCTAssertTrue(error.errorDescription?.contains("completed") ?? false)
  }

  func testTransferControlErrorInvalidBandwidthLimit() {
    let error = TransferControls.TransferControlError.invalidBandwidthLimit(-100.0)

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("-100") ?? false)
  }

  func testTransferControlErrorResumeDataCorrupted() {
    let error = TransferControls.TransferControlError.resumeDataCorrupted

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("Resume data") ?? false)
  }

  func testTransferControlErrorConcurrencyLimitExceeded() {
    let error = TransferControls.TransferControlError.concurrencyLimitExceeded(limit: 4)

    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription?.contains("4") ?? false)
  }

  // MARK: - TransferPriority Tests

  func testTransferPriorityAllCases() {
    let priorities = TransferControls.TransferPriority.allCases

    XCTAssertEqual(priorities.count, 5)
  }

  func testTransferPriorityRawValues() {
    XCTAssertEqual(TransferControls.TransferPriority.background.rank.rawValue, 0)
    XCTAssertEqual(TransferControls.TransferPriority.low.rank.rawValue, 1)
    XCTAssertEqual(TransferControls.TransferPriority.normal.rank.rawValue, 2)
    XCTAssertEqual(TransferControls.TransferPriority.high.rank.rawValue, 3)
    XCTAssertEqual(TransferControls.TransferPriority.critical.rank.rawValue, 4)
  }

  func testTransferPriorityComparable() {
    XCTAssertTrue(TransferControls.TransferPriority.background < .low)
    XCTAssertTrue(TransferControls.TransferPriority.low < .normal)
    XCTAssertTrue(TransferControls.TransferPriority.normal < .high)
    XCTAssertTrue(TransferControls.TransferPriority.high < .critical)
  }

  func testTransferPriorityDescription() {
    XCTAssertEqual(TransferControls.TransferPriority.background.description, "Background")
    XCTAssertEqual(TransferControls.TransferPriority.low.description, "Low")
    XCTAssertEqual(TransferControls.TransferPriority.normal.description, "Normal")
    XCTAssertEqual(TransferControls.TransferPriority.high.description, "High")
    XCTAssertEqual(TransferControls.TransferPriority.critical.description, "Critical")
  }

  // MARK: - BandwidthLimit Tests

  func testBandwidthLimitInitialization() {
    let limit = TransferControls.BandwidthLimit(
      bytesPerSecond: TransferByteRate(1024 * 1024),
      direction: .both,
      timeWindow: 1.0
    )

    XCTAssertEqual(limit.bytesPerSecond.rawValue, 1024 * 1024)
    XCTAssertEqual(limit.timeWindow.rawValue, 1.0)
  }

  func testBandwidthLimitDirection() {
    let directions = TransferControls.BandwidthLimit.Direction.allCases

    XCTAssertEqual(directions.count, 3)
    XCTAssertTrue(directions.contains(.upload))
    XCTAssertTrue(directions.contains(.download))
    XCTAssertTrue(directions.contains(.both))
  }

  func testBandwidthLimitMegabytesPerSecond() {
    let limit = TransferControls.BandwidthLimit.megabytesPerSecond(10, direction: .download)

    XCTAssertEqual(limit.bytesPerSecond.rawValue, 10 * 1_048_576)
  }

  func testBandwidthLimitKilobytesPerSecond() {
    let limit = TransferControls.BandwidthLimit.kilobytesPerSecond(512, direction: .upload)

    XCTAssertEqual(limit.bytesPerSecond.rawValue, 512 * 1024)
  }

  func testBandwidthLimitDescription() {
    let mbLimit = TransferControls.BandwidthLimit.megabytesPerSecond(1)
    XCTAssertTrue(mbLimit.description.contains("MB/s"))

    let kbLimit = TransferControls.BandwidthLimit.kilobytesPerSecond(512)
    XCTAssertTrue(kbLimit.description.contains("KB/s"))

    let bytesLimit = TransferControls.BandwidthLimit(bytesPerSecond: 500)
    XCTAssertTrue(bytesLimit.description.contains("B/s"))
  }

  func testBandwidthLimitHashable() {
    let limit1 = TransferControls.BandwidthLimit(bytesPerSecond: 1024)
    let limit2 = TransferControls.BandwidthLimit(bytesPerSecond: 1024)
    let limit3 = TransferControls.BandwidthLimit(bytesPerSecond: 2048)

    XCTAssertEqual(limit1, limit2)
    XCTAssertNotEqual(limit1, limit3)
  }

  // MARK: - TransferControlConfiguration Tests

  func testDefaultTransferControlConfiguration() {
    let config = TransferControls.TransferControlConfiguration.default

    XCTAssertEqual(config.maxConcurrentTransfers, 4)
    XCTAssertNil(config.defaultBandwidthLimit)
    XCTAssertNil(config.autoRetryConfiguration)
    XCTAssertFalse(config.enableAdaptivePriority.rawValue)
  }

  func testCustomTransferControlConfiguration() {
    let bandwidthLimit = TransferControls.BandwidthLimit.megabytesPerSecond(1)
    let retryConfig = TransferControls.AutoRetryConfiguration(maxRetries: 5)

    let config = TransferControls.TransferControlConfiguration(
      maxConcurrentTransfers: 8,
      defaultBandwidthLimit: bandwidthLimit,
      autoRetryConfiguration: retryConfig,
      enableAdaptivePriority: true
    )

    XCTAssertEqual(config.maxConcurrentTransfers, 8)
    XCTAssertNotNil(config.defaultBandwidthLimit)
    XCTAssertNotNil(config.autoRetryConfiguration)
    XCTAssertTrue(config.enableAdaptivePriority.rawValue)
  }

  // MARK: - AutoRetryConfiguration Tests

  func testAutoRetryConfigurationDefault() {
    let config = TransferControls.AutoRetryConfiguration()

    XCTAssertEqual(config.maxRetries, 3)
    XCTAssertEqual(config.baseDelay, 1.0)
    XCTAssertEqual(config.backoffMultiplier, 2.0)
    XCTAssertEqual(config.maxDelay, 60.0)
  }

  func testAutoRetryConfigurationCustom() {
    let config = TransferControls.AutoRetryConfiguration(
      maxRetries: 5,
      baseDelay: 0.5,
      backoffMultiplier: 1.5,
      maxDelay: 30.0
    )

    XCTAssertEqual(config.maxRetries, 5)
    XCTAssertEqual(config.baseDelay, 0.5)
    XCTAssertEqual(config.backoffMultiplier, 1.5)
    XCTAssertEqual(config.maxDelay, 30.0)
  }

  // MARK: - TransferControlManager Tests

  func testTransferControlManagerInitialization() async {
    let manager = TransferControls.TransferControlManager()
    XCTAssertNotNil(manager)
  }

  func testTransferControlManagerWithConfiguration() async {
    let config = TransferControls.TransferControlConfiguration(maxConcurrentTransfers: 2)
    let manager = TransferControls.TransferControlManager(configuration: config)

    XCTAssertNotNil(manager)
  }

  func testTransferControlManagerRegisterTransfer() async throws {
    let manager = TransferControls.TransferControlManager()
    let transferId = TransferIdentifier()

    let initialState = try await manager.registerTransfer(transferId)

    XCTAssertEqual(initialState, .preparing)
  }

  func testTransferControlManagerGetTransferState() async throws {
    let manager = TransferControls.TransferControlManager()
    let transferId = TransferIdentifier()

    _ = try await manager.registerTransfer(transferId)
    let state = await manager.getTransferState(transferId)

    XCTAssertEqual(state, .preparing)
  }

  func testTransferControlManagerGetTransferStateNotFound() async {
    let manager = TransferControls.TransferControlManager()
    let state = await manager.getTransferState(TransferIdentifier())

    XCTAssertNil(state)
  }

  func testTransferControlManagerUnregisterTransfer() async throws {
    let manager = TransferControls.TransferControlManager()
    let transferId = TransferIdentifier()

    _ = try await manager.registerTransfer(transferId)
    await manager.unregisterTransfer(transferId)

    let state = await manager.getTransferState(transferId)
    XCTAssertNil(state)
  }

  func testTransferControlManagerGetTransferInfo() async throws {
    let manager = TransferControls.TransferControlManager()
    let transferId = TransferIdentifier()

    _ = try await manager.registerTransfer(transferId, priority: .high)
    let info = await manager.getTransferInfo(transferId)

    XCTAssertNotNil(info)
    XCTAssertEqual(info?.transferId, transferId)
    XCTAssertEqual(info?.priority, .high)
  }

  func testTransferControlManagerUpdatePriority() async throws {
    let manager = TransferControls.TransferControlManager()
    let transferId = TransferIdentifier()

    _ = try await manager.registerTransfer(transferId, priority: .normal)
    try await manager.updatePriority(transferId, priority: .critical)

    let info = await manager.getTransferInfo(transferId)
    XCTAssertEqual(info?.priority, .critical)
  }

  func testTransferControlManagerGetTransferStatistics() async throws {
    let manager = TransferControls.TransferControlManager()

    let stats = await manager.getTransferStatistics()

    XCTAssertEqual(stats.totalTransfers, 0)
    XCTAssertEqual(stats.activeTransfers, 0)
  }

  // MARK: - Factory Method Tests

  func testProductionFactory() async {
    let manager = TransferControls.TransferControlManager.production(maxConcurrentTransfers: 16)
    XCTAssertNotNil(manager)
  }

  func testConservativeFactory() async {
    let manager = TransferControls.TransferControlManager.conservative()
    XCTAssertNotNil(manager)
  }

  // MARK: - BandwidthThrottler Tests

  func testBandwidthThrottlerInitialization() {
    let throttler = TransferControls.BandwidthThrottler()
    XCTAssertNotNil(throttler)
  }

  func testBandwidthThrottlerWithGlobalLimit() {
    let globalLimit = TransferControls.BandwidthLimit.megabytesPerSecond(10)
    let throttler = TransferControls.BandwidthThrottler(globalLimit: globalLimit)

    XCTAssertNotNil(throttler)
  }

  func testBandwidthThrottlerSetLimit() async {
    let throttler = TransferControls.BandwidthThrottler()
    let transferId = TransferIdentifier()
    let limit = TransferControls.BandwidthLimit.megabytesPerSecond(1)

    await throttler.setBandwidthLimit(for: transferId, limit: limit)

    // Should not throw
    let result = await throttler.checkBandwidthLimit(
      for: transferId,
      bytes: 1024,
      direction: .both
    )
    XCTAssertNotNil(result)
  }

  func testBandwidthThrottlerRemoveTransfer() async {
    let throttler = TransferControls.BandwidthThrottler()
    let transferId = TransferIdentifier()
    let limit = TransferControls.BandwidthLimit.megabytesPerSecond(1)

    await throttler.setBandwidthLimit(for: transferId, limit: limit)
    await throttler.removeTransfer(transferId)

    // Transfer should be removed
    let result = await throttler.checkBandwidthLimit(
      for: transferId,
      bytes: 1024,
      direction: .both
    )
    XCTAssertTrue(result.allowed.rawValue)
  }

  // MARK: - TransferInfo Tests

  func testTransferInfoEfficiency() {
    let info = TransferControls.TransferInfo(
      transferId: TransferIdentifier(),
      state: .active,
      priority: .normal,
      bandwidthLimit: nil,
      totalDuration: 100.0,
      activeDuration: 80.0,
      pauseCount: 2,
      resumeCount: 2
    )

    XCTAssertEqual(info.efficiency.rawValue, 0.8, accuracy: 0.01)
  }

  func testTransferInfoEfficiencyZeroDuration() {
    let info = TransferControls.TransferInfo(
      transferId: TransferIdentifier(),
      state: .waiting,
      priority: .normal,
      bandwidthLimit: nil,
      totalDuration: 0,
      activeDuration: 0,
      pauseCount: 0,
      resumeCount: 0
    )

    XCTAssertEqual(info.efficiency.rawValue, 0)
  }

  // MARK: - TransferStatistics Tests

  func testTransferStatisticsSuccessRate() {
    let stats = TransferControls.TransferStatistics(
      totalTransfers: 100,
      activeTransfers: 10,
      pausedTransfers: 5,
      completedTransfers: 70,
      failedTransfers: 15,
      stateDistribution: [:],
      priorityDistribution: [:],
      averageActiveDuration: 30.0
    )

    XCTAssertEqual(stats.successRate.rawValue, 70 / 85 * 100, accuracy: 0.01)
  }

  func testTransferStatisticsSuccessRateNoFinished() {
    let stats = TransferControls.TransferStatistics(
      totalTransfers: 10,
      activeTransfers: 10,
      pausedTransfers: 0,
      completedTransfers: 0,
      failedTransfers: 0,
      stateDistribution: [:],
      priorityDistribution: [:],
      averageActiveDuration: 0
    )

    XCTAssertEqual(stats.successRate.rawValue, 0)
  }

  // MARK: - Sendable Conformance Tests

  func testTransferStateSendable() {
    let state: Sendable = TransferControls.TransferState.active
    XCTAssertNotNil(state)
  }

  func testControlActionSendable() {
    let action: Sendable = TransferControls.ControlAction.pause
    XCTAssertNotNil(action)
  }

  func testTransferPrioritySendable() {
    let priority: Sendable = TransferControls.TransferPriority.high
    XCTAssertNotNil(priority)
  }

  func testBandwidthLimitSendable() {
    let limit: Sendable = TransferControls.BandwidthLimit(bytesPerSecond: 1024)
    XCTAssertNotNil(limit)
  }

  func testTransferControlConfigurationSendable() {
    let config: Sendable = TransferControls.TransferControlConfiguration.default
    XCTAssertNotNil(config)
  }
}
