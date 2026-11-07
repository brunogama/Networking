import Foundation
import Network

actor SSETestServerState {
  private var scripts: [SSETestResponseScript]
  private var capturedRequests: [SSECapturedRequest] = []

  init(scripts: [SSETestResponseScript]) {
    self.scripts = scripts
  }

  func nextScript() -> SSETestResponseScript? {
    guard !scripts.isEmpty else {
      return nil
    }

    return scripts.removeFirst()
  }

  func record(_ request: SSECapturedRequest) {
    capturedRequests.append(request)
  }

  func requests() -> [SSECapturedRequest] {
    capturedRequests
  }
}
