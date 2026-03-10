import NetworkingRuntime
import NetworkingTesting
import Foundation

extension GherkinParser {
  func parseFeature(tokens: inout [Token]) throws -> GherkinFeature {
    let tags = try collectFeatureTags(tokens: &tokens)
    guard let featureToken = tokens.first, featureToken.type == .feature else {
      throw BDDError.missingFeature
    }

    let feature = consumeFeatureToken(tokens: &tokens)
    let description = parseDescription(
      tokens: &tokens,
      stopTokens: [.background, .scenario, .scenarioOutline, .tag]
    )
    let background = try parseOptionalBackground(tokens: &tokens)
    let scenarios = try parseScenarios(tokens: &tokens)

    return GherkinFeature(
      name: BDDFeatureName(feature.text),
      description: description,
      tags: tags,
      background: background,
      scenarios: scenarios,
      location: feature.location
    )
  }

  func collectFeatureTags(tokens: inout [Token]) throws -> [Tag] {
    var tags: [Tag] = []

    while let token = tokens.first {
      if token.type == .feature {
        return tags
      }

      if token.type == .tag {
        tags.append(Tag(BDDTagText(token.text)))
        tokens.removeFirst()
        continue
      }

      if isIgnorableToken(token.type) {
        tokens.removeFirst()
        continue
      }

      throw BDDError.syntaxError(
        message: UserMessageText("Expected Feature keyword"),
        location: makeLocation(from: token)
      )
    }

    return tags
  }

  func consumeFeatureToken(
    tokens: inout [Token]
  ) -> (text: String, location: GherkinSourceLocation) {
    let featureToken = tokens.removeFirst()
    return (
      text: featureToken.text,
      location: makeLocation(from: featureToken)
    )
  }

  func parseDescription(
    tokens: inout [Token],
    stopTokens: [TokenType]
  ) -> BDDDescriptionText? {
    var descriptionLines: [String] = []

    while let token = tokens.first, !stopTokens.contains(token.type) {
      guard
        processDescriptionToken(
          token,
          tokens: &tokens,
          descriptionLines: &descriptionLines
        )
      else {
        break
      }
    }

    guard !descriptionLines.isEmpty else {
      return nil
    }

    return BDDDescriptionText(descriptionLines.joined(separator: "\n"))
  }

  func processDescriptionToken(
    _ token: Token,
    tokens: inout [Token],
    descriptionLines: inout [String]
  ) -> Bool {
    if token.type == .text {
      descriptionLines.append(token.text)
      tokens.removeFirst()
      return true
    }

    if isIgnorableToken(token.type) {
      tokens.removeFirst()
      return true
    }

    return false
  }

  func parseOptionalBackground(tokens: inout [Token]) throws -> GherkinBackground? {
    guard shouldParseBackground(tokens: tokens) else {
      return nil
    }

    while tokens.first?.type == .tag {
      tokens.removeFirst()
    }

    guard tokens.first?.type == .background else {
      return nil
    }

    return try parseBackground(tokens: &tokens)
  }

  func shouldParseBackground(tokens: [Token]) -> Bool {
    let firstType = tokens.first?.type
    guard firstType == .background || firstType == .tag else {
      return false
    }

    var peekIndex = 0
    while peekIndex < tokens.count && tokens[peekIndex].type == .tag {
      peekIndex += 1
    }

    return peekIndex < tokens.count && tokens[peekIndex].type == .background
  }

  func parseScenarios(tokens: inout [Token]) throws -> [GherkinScenario] {
    var scenarios: [GherkinScenario] = []

    while !tokens.isEmpty {
      consumeIgnorableTokens(tokens: &tokens)
      guard !tokens.isEmpty else {
        break
      }

      let scenarioTags = collectTags(tokens: &tokens)
      guard let token = tokens.first else {
        break
      }

      guard let scenario = try parseNextScenario(tokens: &tokens, token: token, tags: scenarioTags)
      else {
        break
      }

      scenarios.append(scenario)
    }

    return scenarios
  }

  func consumeIgnorableTokens(tokens: inout [Token]) {
    while tokens.first?.type == .blank || tokens.first?.type == .comment {
      tokens.removeFirst()
    }
  }

  func collectTags(tokens: inout [Token]) -> [Tag] {
    var tags: [Tag] = []
    while tokens.first?.type == .tag {
      tags.append(Tag(BDDTagText(tokens.removeFirst().text)))
    }
    return tags
  }

  func parseNextScenario(
    tokens: inout [Token],
    token: Token,
    tags: [Tag]
  ) throws -> GherkinScenario? {
    switch token.type {
    case .scenario:
      return .scenario(try parseScenario(tokens: &tokens, tags: tags))
    case .scenarioOutline:
      return .outline(try parseScenarioOutline(tokens: &tokens, tags: tags))
    default:
      return nil
    }
  }
}
