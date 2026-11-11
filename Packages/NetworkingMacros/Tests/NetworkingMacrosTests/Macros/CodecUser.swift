import Foundation
import Networking
import NetworkingMacros
import Testing

struct CodecUser: Codable, Equatable, Sendable {
  let displayName: String
  let createdAt: Date
}
