import NetworkingRuntime
import NetworkingTesting
import Foundation

extension GherkinParser {
  func parseBackground(tokens: inout [Token]) throws -> GherkinBackground {
    guard tokens.first?.type == .background else {
      throw BDDError.syntaxError(
        message: UserMessageText("Expected Background keyword"),
        location: tokens.first.map {
          GherkinSourceLocation(
            line: BDDSourceLine($0.line),
            column: BDDSourceColumn($0.column)
          )
        } ?? .unknown
      )
    }

    let bgToken = tokens.removeFirst()
    let location = GherkinSourceLocation(
      line: BDDSourceLine(bgToken.line),
      column: BDDSourceColumn(bgToken.column)
    )

    let steps = try parseSteps(tokens: &tokens)

    return GherkinBackground(
      name: bgToken.text.isEmpty ? nil : BDDDescriptionText(bgToken.text),
      steps: steps,
      location: location
    )
  }

  func parseScenario(
    tokens: inout [Token],
    tags: [Tag]
  ) throws -> ScenarioDefinition {
    guard tokens.first?.type == .scenario else {
      throw BDDError.syntaxError(
        message: UserMessageText("Expected Scenario keyword"),
        location: tokens.first.map {
          GherkinSourceLocation(
            line: BDDSourceLine($0.line),
            column: BDDSourceColumn($0.column)
          )
        } ?? .unknown
      )
    }

    let scenarioToken = tokens.removeFirst()
    let location = GherkinSourceLocation(
      line: BDDSourceLine(scenarioToken.line),
      column: BDDSourceColumn(scenarioToken.column)
    )

    // Parse description (optional)
    var descLines: [String] = []
    while tokens.first?.type == .text {
      descLines.append(tokens.removeFirst().text)
    }
    let description =
      descLines.isEmpty ? nil : BDDDescriptionText(descLines.joined(separator: "\n"))

    let steps = try parseSteps(tokens: &tokens)

    return ScenarioDefinition(
      name: BDDScenarioName(scenarioToken.text),
      description: description,
      tags: tags,
      steps: steps,
      location: location
    )
  }

  func parseScenarioOutline(
    tokens: inout [Token],
    tags: [Tag]
  ) throws -> ScenarioOutlineDefinition {
    guard tokens.first?.type == .scenarioOutline else {
      throw BDDError.syntaxError(
        message: UserMessageText("Expected Scenario Outline keyword"),
        location: tokens.first.map {
          GherkinSourceLocation(
            line: BDDSourceLine($0.line),
            column: BDDSourceColumn($0.column)
          )
        } ?? .unknown
      )
    }

    let outlineToken = tokens.removeFirst()
    let location = GherkinSourceLocation(
      line: BDDSourceLine(outlineToken.line),
      column: BDDSourceColumn(outlineToken.column)
    )

    // Parse description
    var descLines: [String] = []
    while tokens.first?.type == .text {
      descLines.append(tokens.removeFirst().text)
    }
    let description =
      descLines.isEmpty ? nil : BDDDescriptionText(descLines.joined(separator: "\n"))

    let steps = try parseSteps(tokens: &tokens)
    let examples = try parseExamples(tokens: &tokens)

    return ScenarioOutlineDefinition(
      name: BDDScenarioName(outlineToken.text),
      description: description,
      tags: tags,
      steps: steps,
      examples: examples,
      location: location
    )
  }
}
