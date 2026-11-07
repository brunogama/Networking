import Foundation
import Network

struct SSETestResponseScript: Sendable {
  let statusCode: Int
  let headers: [String: String]
  let chunks: [SSETestChunk]

  init(
    statusCode: Int = 200,
    headers: [String: String] = ["Content-Type": "text/event-stream"],
    chunks: [SSETestChunk]
  ) {
    self.statusCode = statusCode
    self.headers = headers
    self.chunks = chunks
  }
}
