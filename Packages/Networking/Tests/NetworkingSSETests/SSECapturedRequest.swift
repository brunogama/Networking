import Foundation
import Network

struct SSECapturedRequest: Sendable {
  let method: String
  let path: String
  let headers: [String: String]
}
