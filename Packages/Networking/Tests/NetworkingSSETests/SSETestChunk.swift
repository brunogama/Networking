import Foundation
import Network

struct SSETestChunk: Sendable {
  let data: Data
  let delay: TimeInterval

  init(_ string: String, delay: TimeInterval = 0) {
    data = Data(string.utf8)
    self.delay = delay
  }
}
