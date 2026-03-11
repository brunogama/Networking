import Testing
import NetworkingCore

@testable import NetworkingBDD

@Suite("GherkinParser Tests")
struct GherkinParserTests {
  @Test("Parser preserves feature tags, background, scenarios, and examples")
  // swiftlint:disable:next function_body_length
  func parsesFeatureWithScenarioOutline() throws {
    let source = """
      @smoke @api
      Feature: User API
        Exercises the parser

        Background:
          Given the base URL is "https://api.example.com"

        @fast
        Scenario: Fetch user
          When I GET "/users/123"
          Then the response status should be 200

        @table
        Scenario Outline: Fetch status for <path>
          When I GET "<path>"
          Then the response status should be <status>

          Examples:
            | path | status |
            | /users/123 | 200 |
            | /users/missing | 404 |
      """

    let feature = try GherkinParser().parse(source: BDDSourceText(source))

    #expect(feature.name == "User API")
    #expect(feature.tags.map { $0.name } == ["@smoke", "@api"])
    #expect(feature.background?.steps.count == 1)
    #expect(feature.background?.steps.first?.keyword == .given)
    #expect(feature.scenarios.count == 2)

    guard case .scenario(let definition) = feature.scenarios[0] else {
      Issue.record("Expected the first parsed scenario to be a concrete scenario")
      return
    }

    #expect(definition.name == "Fetch user")
    #expect(definition.tags.map { $0.name } == ["@fast"])
    #expect(definition.steps.map { $0.keyword } == [StepKeyword.when, StepKeyword.then])

    guard case .outline(let definition) = feature.scenarios[1] else {
      Issue.record("Expected the second parsed scenario to be a scenario outline")
      return
    }

    #expect(definition.name == "Fetch status for <path>")
    #expect(definition.tags.map { $0.name } == ["@table"])
    #expect(
      definition.steps.map { $0.text } == [
        "I GET \"<path>\"",
        "the response status should be <status>",
      ]
    )
    #expect(definition.examples.count == 1)
    #expect(definition.examples[0].headers == ["path", "status"])
    #expect(
      definition.examples[0].rows == [
        ["/users/123", "200"],
        ["/users/missing", "404"],
      ]
    )
  }

  @Test("Parser reports a missing feature declaration")
  func reportsMissingFeature() throws {
    let source = """
      # Comment-only feature file

      """

    do {
      _ = try GherkinParser().parse(source: BDDSourceText(source))
      Issue.record("Expected parsing to fail without a Feature declaration")
    } catch let error as BDDError {
      guard case .missingFeature = error else {
        Issue.record("Expected missingFeature, got \(error)")
        return
      }
    }
  }
}
