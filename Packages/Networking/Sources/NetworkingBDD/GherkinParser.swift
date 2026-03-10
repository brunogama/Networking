import NetworkingRuntime
import NetworkingTesting
import Foundation

// MARK: - Gherkin Parser
// swiftlint:disable file_length type_body_length

/// Parser for Gherkin feature files.
///
/// Parses `.feature` files into `GherkinFeature` AST for execution.
///
/// ## Supported Syntax
///
/// - Feature, Background, Scenario, Scenario Outline
/// - Given, When, Then, And, But steps
/// - Data tables and doc strings
/// - Tags (@smoke, @regression, etc.)
/// - Examples tables for Scenario Outline
///
/// ## Usage
///
/// ```swift
/// let parser = GherkinParser()
/// let feature = try parser.parse(source: BDDSourceText(featureContent))
/// ```
public final class GherkinParser: Sendable {
  // MARK: - Types

  /// Token types for lexer.
  private enum TokenType {
    case feature
    case background
    case scenario
    case scenarioOutline
    case examples
    case given
    case when
    case then
    case and
    case but
    case asterisk
    case tag
    case docStringDelimiter
    case tableRow
    case text
    case blank
    case comment
  }

  /// A parsed token with location.
  private struct Token {
    let type: TokenType
    let text: String
    let line: Int
    let column: Int
  }

  private struct StepAttachments {
    let docString: DocString?
    let dataTable: DataTable?
  }

  private struct DocStringParseResult {
    let lines: [String]
    let terminated: Bool
  }

  private static let lineKeywords: [(String, TokenType)] = [
    ("Feature:", .feature),
    ("Background:", .background),
    ("Scenario Outline:", .scenarioOutline),
    ("Scenario Template:", .scenarioOutline),
    ("Scenario:", .scenario),
    ("Examples:", .examples),
    ("Scenarios:", .examples),
    ("Given ", .given),
    ("When ", .when),
    ("Then ", .then),
    ("And ", .and),
    ("But ", .but),
    ("* ", .asterisk),
  ]

  private static let stepKeywords: [TokenType: StepKeyword] = [
    .given: .given,
    .when: .when,
    .then: .then,
    .and: .and,
    .but: .but,
    .asterisk: .asterisk,
  ]

  // MARK: - Initialization

  public init() {}

  // MARK: - Public Methods

  /// Parses a Gherkin feature file from a string.
  ///
  /// - Parameter source: The Gherkin source text
  /// - Returns: Parsed feature
  /// - Throws: `BDDError` for parsing errors
  public func parse(source: BDDSourceText) throws -> GherkinFeature {
    let lines = source.rawValue.components(separatedBy: .newlines)
    var tokens = tokenize(lines: lines)

    return try parseFeature(tokens: &tokens)
  }

  /// Parses a Gherkin feature file from a file URL.
  ///
  /// - Parameter url: File URL to the feature file
  /// - Returns: Parsed feature
  /// - Throws: `BDDError.fileNotFound` or `BDDError.fileReadError`
  public func parse(url: BDDFileURL) throws -> GherkinFeature {
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw BDDError.fileNotFound(path: BDDSourceFilePath(url.path))
    }

    do {
      let source = try String(contentsOf: url.rawValue, encoding: .utf8)
      var feature = try parse(source: BDDSourceText(source))
      // Update location with file path
      feature = GherkinFeature(
        id: feature.id,
        name: feature.name,
        description: feature.description,
        tags: feature.tags,
        background: feature.background,
        scenarios: feature.scenarios,
        location: GherkinSourceLocation(
          line: feature.location.line,
          column: feature.location.column,
          file: BDDSourceFilePath(url.path)
        )
      )
      return feature
    } catch let error as BDDError {
      throw error
    } catch {
      throw BDDError.fileReadError(path: BDDSourceFilePath(url.path), underlyingError: error)
    }
  }

  // MARK: - Tokenization

  private func tokenize(lines: [String]) -> [Token] {
    var tokens: [Token] = []

    for (lineIndex, line) in lines.enumerated() {
      let lineNumber = lineIndex + 1
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      tokens.append(contentsOf: self.tokens(for: trimmed, lineNumber: lineNumber))
    }

    return tokens
  }

  private func tokens(for line: String, lineNumber: Int) -> [Token] {
    blankTokens(for: line, lineNumber: lineNumber)
      ?? commentTokens(for: line, lineNumber: lineNumber)
      ?? tagTokens(for: line, lineNumber: lineNumber)
      ?? docStringDelimiterTokens(for: line, lineNumber: lineNumber)
      ?? tableRowTokens(for: line, lineNumber: lineNumber)
      ?? [tokenizeLine(line, lineNumber: lineNumber)]
  }

  private func blankTokens(for line: String, lineNumber: Int) -> [Token]? {
    guard line.isEmpty else {
      return nil
    }

    return [Token(type: .blank, text: "", line: lineNumber, column: 1)]
  }

  private func commentTokens(for line: String, lineNumber: Int) -> [Token]? {
    guard line.hasPrefix("#") else {
      return nil
    }

    return [Token(type: .comment, text: line, line: lineNumber, column: 1)]
  }

  private func tagTokens(for line: String, lineNumber: Int) -> [Token]? {
    guard line.hasPrefix("@") else {
      return nil
    }

    return
      line
      .components(separatedBy: .whitespaces)
      .filter { $0.hasPrefix("@") }
      .map { Token(type: .tag, text: $0, line: lineNumber, column: 1) }
  }

  private func docStringDelimiterTokens(for line: String, lineNumber: Int) -> [Token]? {
    guard line.hasPrefix("\"\"\"") || line.hasPrefix("```") else {
      return nil
    }

    return [Token(type: .docStringDelimiter, text: line, line: lineNumber, column: 1)]
  }

  private func tableRowTokens(for line: String, lineNumber: Int) -> [Token]? {
    guard line.hasPrefix("|") else {
      return nil
    }

    return [Token(type: .tableRow, text: line, line: lineNumber, column: 1)]
  }

  private func tokenizeLine(_ line: String, lineNumber: Int) -> Token {
    for (keyword, type) in Self.lineKeywords where line.hasPrefix(keyword) {
      let text = String(line.dropFirst(keyword.count))
      return Token(
        type: type,
        text: text.trimmingCharacters(in: .whitespaces),
        line: lineNumber,
        column: 1
      )
    }

    return Token(type: .text, text: line, line: lineNumber, column: 1)
  }

  // MARK: - Parsing

  private func parseFeature(tokens: inout [Token]) throws -> GherkinFeature {
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

  private func collectFeatureTags(tokens: inout [Token]) throws -> [Tag] {
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

  private func consumeFeatureToken(
    tokens: inout [Token]
  ) -> (text: String, location: GherkinSourceLocation) {
    let featureToken = tokens.removeFirst()
    return (
      text: featureToken.text,
      location: makeLocation(from: featureToken)
    )
  }

  private func parseDescription(
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

  private func processDescriptionToken(
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

  private func parseOptionalBackground(tokens: inout [Token]) throws -> GherkinBackground? {
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

  private func shouldParseBackground(tokens: [Token]) -> Bool {
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

  private func parseScenarios(tokens: inout [Token]) throws -> [GherkinScenario] {
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

  private func consumeIgnorableTokens(tokens: inout [Token]) {
    while tokens.first?.type == .blank || tokens.first?.type == .comment {
      tokens.removeFirst()
    }
  }

  private func collectTags(tokens: inout [Token]) -> [Tag] {
    var tags: [Tag] = []
    while tokens.first?.type == .tag {
      tags.append(Tag(BDDTagText(tokens.removeFirst().text)))
    }
    return tags
  }

  private func parseNextScenario(
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

  private func parseBackground(tokens: inout [Token]) throws -> GherkinBackground {
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

  private func parseScenario(
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

  private func parseScenarioOutline(
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

  private func parseSteps(tokens: inout [Token]) throws -> [GherkinStep] {
    var steps: [GherkinStep] = []

    while !tokens.isEmpty {
      consumeBlankTokens(tokens: &tokens)
      guard let token = tokens.first else {
        break
      }

      guard let keyword = stepKeyword(for: token.type) else {
        break
      }

      tokens.removeFirst()
      let stepLocation = makeLocation(from: token)
      let attachments = try parseStepAttachments(tokens: &tokens)

      steps.append(
        GherkinStep(
          keyword: keyword,
          text: BDDStepText(token.text),
          dataTable: attachments.dataTable,
          docString: attachments.docString,
          location: stepLocation
        )
      )
    }

    return steps
  }

  private func consumeBlankTokens(tokens: inout [Token]) {
    while tokens.first?.type == .blank {
      tokens.removeFirst()
    }
  }

  private func parseStepAttachments(tokens: inout [Token]) throws -> StepAttachments {
    consumeBlankTokens(tokens: &tokens)

    if tokens.first?.type == .docStringDelimiter {
      return StepAttachments(docString: try parseDocString(tokens: &tokens), dataTable: nil)
    }

    if tokens.first?.type == .tableRow {
      return StepAttachments(docString: nil, dataTable: try parseDataTable(tokens: &tokens))
    }

    return StepAttachments(docString: nil, dataTable: nil)
  }

  private func parseDocString(tokens: inout [Token]) throws -> DocString {
    guard tokens.first?.type == .docStringDelimiter else {
      throw BDDError.syntaxError(
        message: UserMessageText("Expected doc string delimiter"),
        location: tokens.first.map(makeLocation(from:)) ?? .unknown
      )
    }

    let startToken = tokens.removeFirst()
    let location = makeLocation(from: startToken)
    let result = consumeDocStringContent(tokens: &tokens)

    guard result.terminated else {
      throw BDDError.unterminatedDocString(location: location)
    }

    return DocString(
      contentType: docStringContentType(for: startToken.text),
      content: BDDDocContent(result.lines.joined(separator: "\n"))
    )
  }

  private func docStringContentType(for delimiterText: String) -> BDDDocContentType? {
    let delimiter = delimiterText.trimmingCharacters(in: .whitespaces)
    guard delimiter.count > 3 else {
      return nil
    }

    return BDDDocContentType(String(delimiter.dropFirst(3)))
  }

  private func consumeDocStringContent(tokens: inout [Token]) -> DocStringParseResult {
    var lines: [String] = []

    while !tokens.isEmpty {
      let token = tokens.removeFirst()
      if token.type == .docStringDelimiter {
        return DocStringParseResult(lines: lines, terminated: true)
      }
      lines.append(token.text)
    }

    return DocStringParseResult(lines: lines, terminated: false)
  }

  private func parseDataTable(tokens: inout [Token]) throws -> DataTable {
    var rows: [[BDDExamplesCell]] = []

    while tokens.first?.type == .tableRow {
      let token = tokens.removeFirst()
      let cells = parseTableRow(token.text)
      rows.append(cells)
    }

    return DataTable(rows: rows)
  }

  private func parseTableRow(_ line: String) -> [BDDExamplesCell] {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    var cells: [BDDExamplesCell] = []

    // Split by | and trim each cell
    let parts = trimmed.split(separator: "|", omittingEmptySubsequences: false)
    for part in parts {
      let cell = part.trimmingCharacters(in: .whitespaces)
      if !cell.isEmpty {
        cells.append(BDDExamplesCell(cell))
      }
    }

    return cells
  }

  private func parseExamples(tokens: inout [Token]) throws -> [ExamplesTable] {
    var examples: [ExamplesTable] = []

    while !tokens.isEmpty {
      consumeBlankTokens(tokens: &tokens)
      let exampleTags = collectTags(tokens: &tokens)

      guard tokens.first?.type == .examples else {
        break
      }

      let examplesToken = tokens.removeFirst()
      let location = makeLocation(from: examplesToken)
      consumeBlankTokens(tokens: &tokens)
      let rows = consumeExampleRows(tokens: &tokens)

      guard !rows.isEmpty else {
        throw BDDError.invalidExamples(
          reason: UserMessageText("Examples table is empty"),
          location: location
        )
      }

      let headers = rows[0].map { BDDExamplesHeader($0.rawValue) }
      let dataRows = Array(rows.dropFirst())

      examples.append(
        ExamplesTable(
          name: examplesToken.text.isEmpty ? nil : BDDExamplesName(examplesToken.text),
          tags: exampleTags,
          headers: headers,
          rows: dataRows,
          location: location
        )
      )
    }

    return examples
  }

  private func consumeExampleRows(tokens: inout [Token]) -> [[BDDExamplesCell]] {
    var rows: [[BDDExamplesCell]] = []
    while tokens.first?.type == .tableRow {
      let token = tokens.removeFirst()
      rows.append(parseTableRow(token.text))
    }
    return rows
  }

  /// Maps a token type to a step keyword, returning nil if not a step token.
  private func stepKeyword(for tokenType: TokenType) -> StepKeyword? {
    Self.stepKeywords[tokenType]
  }

  private func isIgnorableToken(_ tokenType: TokenType) -> Bool {
    tokenType == .blank || tokenType == .comment
  }

  private func makeLocation(from token: Token) -> GherkinSourceLocation {
    GherkinSourceLocation(
      line: BDDSourceLine(token.line),
      column: BDDSourceColumn(token.column)
    )
  }
}
// swiftlint:enable file_length type_body_length
