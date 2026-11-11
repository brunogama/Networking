import Foundation
import XCTest
@testable import NetworkingRuntime
import NetworkingTesting

#if !os(Linux)
extension BackgroundTransferEventRecorder {
  struct CompletionEvent {
    let task: URLSessionTask
    let completion: BackgroundTransferCompletion
  }
}
#endif
