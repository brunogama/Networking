import Foundation
@testable import NetworkingRuntime
import NetworkingDSL
import NetworkingRuntimeDSL
import NetworkingTesting
import Testing

@Suite("NetworkActor Tests")
struct NetworkActorTests {
    @Test("NetworkActor shared instance exists")
    func sharedInstanceExists() async {
        // Verify the shared instance is accessible
        let actor = NetworkActor.shared
        #expect(actor != nil)
    }

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
        @NetworkActor
        class StateManager {
            var value = 0

            func increment() {
                value += 1
            }

            func getValue() -> Int {
                return value
            }
        }

        let manager = StateManager()
        await manager.increment()
        await manager.increment()
        await manager.increment()
        let result = await manager.getValue()
        #expect(result == 3)
    }
}
