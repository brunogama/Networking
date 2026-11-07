import Foundation
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

@Suite("NetworkActor Tests")
struct NetworkActorTests {
  @Test("NetworkActor-annotated function executes on actor")
  func annotatedFunctionExecution() async {
    @NetworkActor
    func updateState() -> String {
      return "updated"
    }

    let result = await updateState()
    #expect(result == "updated")
  }

  @Test("NetworkActor-annotated class serializes access")
  func annotatedClassSerializesAccess() async {

    let manager = StateManager()
    await manager.increment()
    await manager.increment()
    await manager.increment()
    let result = await manager.getValue()
    #expect(result == 3)
  }
}
