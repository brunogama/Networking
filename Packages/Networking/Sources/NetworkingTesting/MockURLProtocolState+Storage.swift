import Foundation

extension MockURLProtocolState {
  struct Storage: Sendable {
    var entries: [Entry] = []
    var requests: [URLRequest] = []

    mutating func consume(_ id: UUID) -> MockURLRequestStub? {
      guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
      let stub = entries[index].stub
      entries[index].uses += 1
      if let limit = stub.maxUsageCount, entries[index].uses >= limit.rawValue {
        entries.remove(at: index)
      }
      return stub
    }
  }
}
