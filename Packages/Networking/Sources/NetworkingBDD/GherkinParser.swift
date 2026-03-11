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
/// let feature = try parser.parse(source: BDDSourceText(featureContent))
/// ```
public final class GherkinParser: Sendable {
  // MARK: - Types

  /// Token types for lexer.
  enum TokenType {
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
  struct Token {
    let type: TokenType
    let text: String
    let line: Int
    let column: Int
  }

  struct StepAttachments {
    let docString: DocString?
    let dataTable: DataTable?
  }

  struct DocStringParseResult {
    let lines: [String]
    let terminated: Bool
  }

  static let lineKeywords: [(String, TokenType)] = [
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

  static let stepKeywords: [TokenType: StepKeyword] = [
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

  /// Maps a token type to a step keyword, returning nil if not a step token.
  func stepKeyword(for tokenType: TokenType) -> StepKeyword? {
    Self.stepKeywords[tokenType]
  }

  func isIgnorableToken(_ tokenType: TokenType) -> Bool {
    tokenType == .blank || tokenType == .comment
  }

  func makeLocation(from token: Token) -> GherkinSourceLocation {
    GherkinSourceLocation(
      line: BDDSourceLine(token.line),
      column: BDDSourceColumn(token.column)
    )
  }
}
