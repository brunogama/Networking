import Foundation
import XCTest
@testable import NetworkingRuntime
import NetworkingTesting

#if !os(Linux)
extension BackgroundTransferEventRecorder {
  struct ProgressEvent {
    let task: URLSessionDownloadTask
    let totalBytesWritten: Int64
    let totalBytesExpected: Int64
  }
}
#endif
