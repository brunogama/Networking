import Foundation
import Testing

@testable import NetworkingBDD

@Suite("StepRegistry Tests", .serialized)
struct StepRegistryTests {
  @Test("Registry captures regex groups and executes the matched implementation")
  func executesMatchedStep() async throws {
    let registry = StepRegistry()
    let context = ScenarioContext()

    try registry.given("the user id is (\\d+)") { stepContext, matches in
      stepContext.setValue(matches[0].rawValue, forKey: "userID")
    }

    let step = GherkinStep(keyword: .given, text: "the user id is 42")
    let (definition, captures) = try registry.findMatch(for: step, semanticType: .given)

    #expect(definition.pattern == "the user id is (\\d+)")
    #expect(definition.stepType == .given)
    #expect(captures == ["42"])
    #expect(registry.hasDefinition(for: step.text, type: .given).rawValue)

    try await registry.execute(step: step, semanticType: .given, context: context)

    let storedValue: String? = context.getValue(forKey: "userID")
    #expect(storedValue == "42")
  }

  @Test("Registry surfaces ambiguous matches and clear removes registrations")
  func reportsAmbiguousMatchesAndSupportsClear() throws {
    let registry = StepRegistry()
    let step = GherkinStep(keyword: .given, text: "the user id is 42")

    try registry.given("the user id is (\\d+)") { _, _ in }
    try registry.given("the user id is 42") { _, _ in }

    do {
      _ = try registry.findMatch(for: step, semanticType: .given)
      Issue.record("Expected ambiguous step lookup to fail")
    } catch let error as BDDError {
      guard case .ambiguousStep(let text, let matchCount) = error else {
        Issue.record("Expected ambiguousStep, got \(error)")
        return
      }

      #expect(text.rawValue == step.text.rawValue)
      #expect(matchCount == 2)
    }

    registry.clear()
    #expect(!registry.hasDefinition(for: step.text, type: .given).rawValue)
  }
}
