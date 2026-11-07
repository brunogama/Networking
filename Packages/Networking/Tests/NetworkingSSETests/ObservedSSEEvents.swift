import Foundation
import NetworkingCore
import Testing
@testable import NetworkingSSE

actor ObservedSSEEvents {
  private var events: [SSEConnectionEvent] = []
  private let opened = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))

  func append(_ event: SSEConnectionEvent) {
    events.append(event)
    if event == .open { opened.continuation.yield(()) }
  }

  func waitUntilOpened() async {
    for await _ in opened.stream { break }
  }

  func snapshot() -> [SSEConnectionEvent] {
    events
  }
}
