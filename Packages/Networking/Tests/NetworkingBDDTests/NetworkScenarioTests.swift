import Foundation
import Testing

@testable import NetworkingBDD
import NetworkingRuntime

@Suite("NetworkScenario Tests")
struct NetworkScenarioTests {
  @Test("Inline steps share state across Given, When, and Then")
  func inlineStepsRunAgainstSharedContext() async throws {
    let expectedURL = URL(string: "https://api.example.com")!

    let workflow = scenario("Fetch profile", tags: .smoke)
      .given(
        given("record request") { context in
          let request = HTTPRequest(
            method: .get,
            url: expectedURL.appendingPathComponent("profile")
          )
          context.recordRequest(request)
        }
      )
      .when(
        when("record response") { context in
          let request = try context.requireRequest()
          let response = HTTPResponse(
            request: request,
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: Data(#"{"ok":true}"#.utf8)
          )

          context.recordRequest(request)
          context.recordResponse(response)
        }
      )
      .then(
        then("verify recorded response") { context in
          let request = try context.requireRequest()
          let response = try context.requireResponse()

          #expect(request.url == expectedURL.appendingPathComponent("profile"))
          #expect(response.status == .ok)
          #expect(response.headers["Content-Type"] == "application/json")
          #expect(context.lastError == nil)
          #expect(!context.requestHistory.isEmpty)
          #expect(context.requestHistory.last?.url == expectedURL.appendingPathComponent("profile"))
          #expect(context.responseHistory.count == 1)
        }
      )

    let result = try await workflow.run(with: ScenarioContext())

    #expect(result.passed)
    #expect(result.passedCount == 3)
    #expect(result.failedCount == 0)
    #expect(result.stepResults.map { $0.step.keyword } == [StepKeyword.given, .when, .then])
    #expect(result.stepResults.allSatisfy { $0.result.isPassed })
    #expect(result.scenario.name == "Fetch profile")
  }
}
