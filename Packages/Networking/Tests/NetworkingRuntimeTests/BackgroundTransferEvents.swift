import Foundation
import XCTest
@testable import NetworkingRuntime
import NetworkingTesting

#if !os(Linux)
struct BackgroundTransferEvents {
  let progress: BackgroundTransferEventRecorder.ProgressEvent?
  let completion: BackgroundTransferEventRecorder.CompletionEvent?
  let order: [String]
}
#endif
