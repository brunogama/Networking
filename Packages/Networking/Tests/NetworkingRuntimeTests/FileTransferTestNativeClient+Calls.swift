import Foundation
import XCTest
@testable import NetworkingRuntime
import NetworkingTesting

extension FileTransferTestNativeClient {
  struct Calls: Sendable {
    var execute = 0
    var upload = 0
    var download = 0
    var uploadedFileURL: URL?
    var uploadRequestHasBody = false
  }
}
