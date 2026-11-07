import Foundation
import XCTest
@testable import NetworkingRuntime
import NetworkingTesting

#if !os(Linux)
actor BackgroundTransferEventRecorder {

  private(set) var progress: ProgressEvent?
  private(set) var completion: CompletionEvent?
  private var order: [String] = []

  var events: BackgroundTransferEvents {
    BackgroundTransferEvents(progress: progress, completion: completion, order: order)
  }

  func recordProgress(
    task: URLSessionDownloadTask,
    totalBytesWritten: Int64,
    totalBytesExpected: Int64
  ) {
    progress = ProgressEvent(
      task: task,
      totalBytesWritten: totalBytesWritten,
      totalBytesExpected: totalBytesExpected
    )
    order.append("progress")
  }

  func recordCompletion(
    task: URLSessionTask,
    completion: BackgroundTransferCompletion
  ) {
    self.completion = CompletionEvent(
      task: task,
      completion: completion
    )
    order.append("completion")
  }
}
#endif
