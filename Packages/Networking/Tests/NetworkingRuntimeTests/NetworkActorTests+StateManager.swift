import Foundation
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

extension NetworkActorTests {
  @NetworkActor
  final class StateManager {
    var value = 0

    func increment() {
      value += 1
    }

    func getValue() -> Int {
      return value
    }
  }
}
