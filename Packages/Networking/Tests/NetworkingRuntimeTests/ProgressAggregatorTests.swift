import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import Testing

@Suite("Progress aggregation")
struct ProgressAggregatorTests {
  @Test(arguments: [false, true])
  func aggregatorTracksOnlyActiveTransfers(completed: Bool) async {
    let events = AsyncStream<TransferProgress>.makeStream()
    let aggregator = ProgressAggregator { events.continuation.yield($0) }
    await aggregator.updateProgress(
      for: TransferIdentifier(),
      progress: TransferProgress(
        totalBytes: 1000,
        transferredBytes: 500,
        phase: completed ? .completed : .downloading
      )
    )
    await aggregator.updateProgress(
      for: TransferIdentifier(),
      progress: TransferProgress(totalBytes: 2000, transferredBytes: 1000, phase: .downloading)
    )
    events.continuation.finish()
    var updates: [TransferProgress] = []
    for await update in events.stream { updates.append(update) }
    #expect(updates.count == 2)
    #expect(updates.last?.totalBytes == (completed ? 2000 : 3000))
    #expect(updates.last?.transferredBytes == (completed ? 1000 : 1500))
    #expect(updates.last?.progress == 0.5)
  }
}
