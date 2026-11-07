import Foundation

extension MockURLProtocolState {
  struct Entry: Sendable {
    let id = UUID()
    let stub: MockURLRequestStub
    var uses = 0
  }
}
