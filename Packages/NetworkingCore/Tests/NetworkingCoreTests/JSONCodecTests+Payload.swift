import Foundation
import NetworkingCore
import Testing

extension JSONCodecTests {
  struct Payload: Codable, Equatable, Sendable {
    let createdAt: Date
    let requestNumber: Int
  }
}
