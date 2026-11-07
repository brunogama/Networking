import Foundation
import Network

enum SSETestServerError: Error {
  case invalidBaseURL
  case invalidRequest
  case connectionClosed
}
