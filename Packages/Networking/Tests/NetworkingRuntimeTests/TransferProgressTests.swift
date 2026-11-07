import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import Testing

@Suite("Transfer progress values")
struct TransferProgressTests {
  @Test(arguments: [Int64(-100), 0, 250, 500, 1000, 1500])
  func fractionIsBounded(bytes: Int64) {
    let progress = TransferProgress(
      totalBytes: 1000,
      transferredBytes: TransferByteCount(bytes),
      phase: .downloading
    )
    #expect(progress.progress.rawValue == min(1, max(0, Double(bytes) / 1000)))
  }

  @Test(arguments: [TransferByteCount?.none, .some(0)])
  func unknownTotalReflectsCompletion(total: TransferByteCount?) {
    let active = TransferProgress(totalBytes: total, transferredBytes: 0, phase: .downloading)
    let complete = TransferProgress(totalBytes: total, transferredBytes: 0, phase: .completed)
    #expect(active.progress == 0)
    #expect(complete.progress == 1)
    #expect(complete.estimatedTimeRemaining == nil)
  }

  @Test func estimateRequiresSpeedAndRemainingBytes() {
    let progress = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 250,
      phase: .downloading,
      bytesPerSecond: 100
    )
    let noSpeed = TransferProgress(totalBytes: 1000, transferredBytes: 250, phase: .downloading)
    let completed = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 1000,
      phase: .completed,
      bytesPerSecond: 100
    )
    #expect(progress.estimatedTimeRemaining == 7.5)
    #expect(noSpeed.estimatedTimeRemaining == nil)
    #expect(completed.estimatedTimeRemaining == nil)
  }

  @Test func largeCountsRemainRepresentable() {
    let total = Int64.max / 2
    let progress = TransferProgress(
      totalBytes: TransferByteCount(total),
      transferredBytes: TransferByteCount(total / 2),
      phase: .downloading
    )
    #expect(progress.progress == 0.5)
  }

  @Test func equalityAndHashingIncludeMeasurements() {
    let timestamp = Date(timeIntervalSince1970: 1000)
    let first = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 500,
      phase: .downloading,
      timestamp: timestamp
    )
    let same = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 500,
      phase: .downloading,
      timestamp: timestamp
    )
    let changed = TransferProgress(
      totalBytes: 1000,
      transferredBytes: 600,
      phase: .downloading,
      timestamp: timestamp
    )
    #expect(first == same)
    #expect(first != changed)
    #expect(Set([first, same, changed]).count == 2)
  }
}
