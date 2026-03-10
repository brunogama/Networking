import NetworkingRuntime
import NetworkingTesting
import Foundation

// MARK: - Gherkin Parser

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
/// let feature = try parser.parse(source: featureContent)
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

  // MARK: - Initialization

  public init() {}

  // MARK: - Public Methods

  /// Parses a Gherkin feature file from a string.
  ///
  /// - Parameter source: The Gherkin source text
  /// - Returns: Parsed feature
  /// - Throws: `BDDError` for parsing errors
  public func parse(source: String) throws -> GherkinFeature {
    let lines = source.components(separatedBy: .newlines)
    var tokens = tokenize(lines: lines)

    return try parseFeature(tokens: &tokens)
  }

  /// Parses a Gherkin feature file from a URL.
  ///
  /// - Parameter url: URL to the feature file
  /// - Returns: Parsed feature
  /// - Throws: `BDDError.fileNotFound` or `BDDError.fileReadError`
  public func parse(url: URL) throws -> GherkinFeature {
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw BDDError.fileNotFound(path: url.path)
    }

    do {
      let source = try String(contentsOf: url, encoding: .utf8)
      var feature = try parse(source: source)
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
          file: url.path
        )
      )
      return feature
    } catch let error as BDDError {
      throw error
    } catch {
      throw BDDError.fileReadError(path: url.path, underlyingError: error)
    }
  }

  // MARK: - Tokenization

  private func tokenize(lines: [String]) -> [Token] {
    var tokens: [Token] = []

    for (lineIndex, line) in lines.enumerated() {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      let lineNumber = lineIndex + 1

      if trimmed.isEmpty {
        tokens.append(Token(type: .blank, text: "", line: lineNumber, column: 1))
        continue
      }

      if trimmed.hasPrefix("#") {
        tokens.append(Token(type: .comment, text: trimmed, line: lineNumber, column: 1))
        continue
      }

      if trimmed.hasPrefix("@") {
        // Parse tags
        let tagStrings = trimmed.components(separatedBy: .whitespaces)
          .filter { $0.hasPrefix("@") }
        for tag in tagStrings {
          tokens.append(Token(type: .tag, text: tag, line: lineNumber, column: 1))
        }
        continue
      }

      if trimmed.hasPrefix("\"\"\"") || trimmed.hasPrefix("```") {
        tokens.append(
          Token(
            type: .docStringDelimiter,
            text: trimmed,
            line: lineNumber,
            column: 1
          )
        )
        continue
      }

      if trimmed.hasPrefix("|") {
        tokens.append(Token(type: .tableRow, text: trimmed, line: lineNumber, column: 1))
        continue
      }

      let token = tokenizeLine(trimmed, lineNumber: lineNumber)
      tokens.append(token)
    }

    return tokens
  }

  private func tokenizeLine(_ line: String, lineNumber: Int) -> Token {
    let keywords: [(String, TokenType)] = [
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

    for (keyword, type) in keywords {
      if line.hasPrefix(keyword) {
        let text = String(line.dropFirst(keyword.count))
        return Token(
          type: type,
          text: text.trimmingCharacters(in: .whitespaces),
          line: lineNumber,
          column: 1
        )
      }
    }

    return Token(type: .text, text: line, line: lineNumber, column: 1)
  }

  // MARK: - Parsing

  private func parseFeature(tokens: inout [Token]) throws -> GherkinFeature {
    var tags: [Tag] = []

    // Skip blanks and comments, collect tags
    while !tokens.isEmpty {
      let token = tokens.first!
      switch token.type {
      case .blank, .comment:
        tokens.removeFirst()
      case .tag:
        tags.append(Tag(token.text))
        tokens.removeFirst()
      case .feature:
        break
      default:
        throw BDDError.syntaxError(
          message: "Expected Feature keyword",
          location: GherkinSourceLocation(line: token.line, column: token.column)
        )
      }

      if tokens.first?.type == .feature {
        break
      }
    }

    guard !tokens.isEmpty, tokens.first?.type == .feature else {
      throw BDDError.missingFeature
    }

    let featureToken = tokens.removeFirst()
    let featureName = featureToken.text
    let location = GherkinSourceLocation(
      line: featureToken.line,
      column: featureToken.column
    )

    // Parse feature description (lines until Background/Scenario)
    var description: String?
    var descLines: [String] = []

    while !tokens.isEmpty {
      let token = tokens.first!
      switch token.type {
      case .blank, .comment:
        tokens.removeFirst()
      case .text:
        descLines.append(token.text)
        tokens.removeFirst()
      default:
        break
      }

      if let nextToken = tokens.first,
        [.background, .scenario, .scenarioOutline, .tag].contains(nextToken.type)
      {
        break
      }
    }

    if !descLines.isEmpty {
      description = descLines.joined(separator: "\n")
    }

    // Parse background
    var background: GherkinBackground?
    if tokens.first?.type == .background || (tokens.first?.type == .tag) {
      // Check if next non-tag is background
      var peekIndex = 0
      while peekIndex < tokens.count && tokens[peekIndex].type == .tag {
        peekIndex += 1
      }
      if peekIndex < tokens.count && tokens[peekIndex].type == .background {
        // Skip tags for background (backgrounds don't have tags)
        while tokens.first?.type == .tag {
          tokens.removeFirst()
        }
        background = try parseBackground(tokens: &tokens)
      }
    }

    if tokens.first?.type == .background {
      background = try parseBackground(tokens: &tokens)
    }

    // Parse scenarios
    var scenarios: [GherkinScenario] = []

    while !tokens.isEmpty {
      // Skip blanks and comments
      while tokens.first?.type == .blank || tokens.first?.type == .comment {
        tokens.removeFirst()
      }

      if tokens.isEmpty {
        break
      }

      // Collect scenario tags
      var scenarioTags: [Tag] = []
      while tokens.first?.type == .tag {
        scenarioTags.append(Tag(tokens.removeFirst().text))
      }

      guard let token = tokens.first else {
        break
      }

      switch token.type {
      case .scenario:
        let scenario = try parseScenario(tokens: &tokens, tags: scenarioTags)
        scenarios.append(.scenario(scenario))
      case .scenarioOutline:
        let outline = try parseScenarioOutline(tokens: &tokens, tags: scenarioTags)
        scenarios.append(.outline(outline))
      case .blank, .comment:
        tokens.removeFirst()
      default:
        break
      }
    }

    return GherkinFeature(
      name: featureName,
      description: description,
      tags: tags,
      background: background,
      scenarios: scenarios,
      location: location
    )
  }

  private func parseBackground(tokens: inout [Token]) throws -> GherkinBackground {
    guard tokens.first?.type == .background else {
      throw BDDError.syntaxError(
        message: "Expected Background keyword",
        location: tokens.first.map {
          GherkinSourceLocation(line: $0.line, column: $0.column)
        } ?? .unknown
      )
    }

    let bgToken = tokens.removeFirst()
    let location = GherkinSourceLocation(line: bgToken.line, column: bgToken.column)

    let steps = try parseSteps(tokens: &tokens)

    return GherkinBackground(
      name: bgToken.text.isEmpty ? nil : bgToken.text,
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
        message: "Expected Scenario keyword",
        location: tokens.first.map {
          GherkinSourceLocation(line: $0.line, column: $0.column)
        } ?? .unknown
      )
    }

    let scenarioToken = tokens.removeFirst()
    let location = GherkinSourceLocation(line: scenarioToken.line, column: scenarioToken.column)

    // Parse description (optional)
    var descLines: [String] = []
    while tokens.first?.type == .text {
      descLines.append(tokens.removeFirst().text)
    }
    let description = descLines.isEmpty ? nil : descLines.joined(separator: "\n")

    let steps = try parseSteps(tokens: &tokens)

    return ScenarioDefinition(
      name: scenarioToken.text,
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
        message: "Expected Scenario Outline keyword",
        location: tokens.first.map {
          GherkinSourceLocation(line: $0.line, column: $0.column)
        } ?? .unknown
      )
    }

    let outlineToken = tokens.removeFirst()
    let location = GherkinSourceLocation(line: outlineToken.line, column: outlineToken.column)

    // Parse description
    var descLines: [String] = []
    while tokens.first?.type == .text {
      descLines.append(tokens.removeFirst().text)
    }
    let description = descLines.isEmpty ? nil : descLines.joined(separator: "\n")

    let steps = try parseSteps(tokens: &tokens)
    let examples = try parseExamples(tokens: &tokens)

    return ScenarioOutlineDefinition(
      name: outlineToken.text,
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
      // Skip blanks
      while tokens.first?.type == .blank {
        tokens.removeFirst()
      }

      guard let token = tokens.first else {
        break
      }

      // Map token type to step keyword, or exit if not a step
      guard let keyword = stepKeyword(for: token.type) else {
        break
      }

      tokens.removeFirst()
      let stepLocation = GherkinSourceLocation(line: token.line, column: token.column)

      // Check for doc string
      var docString: DocString?
      var dataTable: DataTable?

      // Skip blanks
      while tokens.first?.type == .blank {
        tokens.removeFirst()
      }

      if tokens.first?.type == .docStringDelimiter {
        docString = try parseDocString(tokens: &tokens)
      } else if tokens.first?.type == .tableRow {
        dataTable = try parseDataTable(tokens: &tokens)
      }

      steps.append(
        GherkinStep(
          keyword: keyword,
          text: token.text,
          dataTable: dataTable,
          docString: docString,
          location: stepLocation
        )
      )
    }

    return steps
  }

  private func parseDocString(tokens: inout [Token]) throws -> DocString {
    guard tokens.first?.type == .docStringDelimiter else {
      throw BDDError.syntaxError(
        message: "Expected doc string delimiter",
        location: tokens.first.map {
          GherkinSourceLocation(line: $0.line, column: $0.column)
        } ?? .unknown
      )
    }

    let startToken = tokens.removeFirst()
    var contentType: String?

    // Check for content type (e.g., ```json)
    let delimiter = startToken.text.trimmingCharacters(in: .whitespaces)
    if delimiter.count > 3 {
      contentType = String(delimiter.dropFirst(3))
    }

    var lines: [String] = []
    let location = GherkinSourceLocation(line: startToken.line, column: startToken.column)

    while !tokens.isEmpty {
      let token = tokens.removeFirst()
      if token.type == .docStringDelimiter {
        break
      }
      lines.append(token.text)
    }

    if tokens.isEmpty && lines.last?.contains("\"\"\"") != true
      && lines.last?.contains("```") != true
    {
      throw BDDError.unterminatedDocString(location: location)
    }

    return DocString(contentType: contentType, content: lines.joined(separator: "\n"))
  }

  private func parseDataTable(tokens: inout [Token]) throws -> DataTable {
    var rows: [[String]] = []

    while tokens.first?.type == .tableRow {
      let token = tokens.removeFirst()
      let cells = parseTableRow(token.text)
      rows.append(cells)
    }

    return DataTable(rows: rows)
  }

  private func parseTableRow(_ line: String) -> [String] {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    var cells: [String] = []

    // Split by | and trim each cell
    let parts = trimmed.split(separator: "|", omittingEmptySubsequences: false)
    for part in parts {
      let cell = part.trimmingCharacters(in: .whitespaces)
      if !cell.isEmpty {
        cells.append(cell)
      }
    }

    return cells
  }

  private func parseExamples(tokens: inout [Token]) throws -> [ExamplesTable] {
    var examples: [ExamplesTable] = []

    while !tokens.isEmpty {
      // Skip blanks
      while tokens.first?.type == .blank {
        tokens.removeFirst()
      }

      // Collect example tags
      var exampleTags: [Tag] = []
      while tokens.first?.type == .tag {
        exampleTags.append(Tag(tokens.removeFirst().text))
      }

      guard tokens.first?.type == .examples else {
        break
      }

      let examplesToken = tokens.removeFirst()
      let location = GherkinSourceLocation(
        line: examplesToken.line,
        column: examplesToken.column
      )

      // Skip blanks
      while tokens.first?.type == .blank {
        tokens.removeFirst()
      }

      // Parse table
      var rows: [[String]] = []
      while tokens.first?.type == .tableRow {
        let token = tokens.removeFirst()
        rows.append(parseTableRow(token.text))
      }

      guard !rows.isEmpty else {
        throw BDDError.invalidExamples(
          reason: "Examples table is empty",
          location: location
        )
      }

      let headers = rows[0]
      let dataRows = Array(rows.dropFirst())

      examples.append(
        ExamplesTable(
          name: examplesToken.text.isEmpty ? nil : examplesToken.text,
          tags: exampleTags,
          headers: headers,
          rows: dataRows,
          location: location
        )
      )
    }

    return examples
  }

  /// Maps a token type to a step keyword, returning nil if not a step token.
  private func stepKeyword(for tokenType: TokenType) -> StepKeyword? {
    switch tokenType {
    case .given:
      return .given
    case .when:
      return .when
    case .then:
      return .then
    case .and:
      return .and
    case .but:
      return .but
    case .asterisk:
      return .asterisk
    case .feature, .background, .scenario, .scenarioOutline, .examples,
      .tag, .docStringDelimiter, .tableRow, .text, .blank, .comment:
      return nil
    }
  }
}
