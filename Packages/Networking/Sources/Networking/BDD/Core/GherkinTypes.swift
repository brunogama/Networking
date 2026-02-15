import Foundation

// MARK: - Gherkin AST Types

/// Represents a complete Gherkin feature file.
///
/// A feature is the top-level container in Gherkin that groups related scenarios
/// together under a common business capability or user story.
///
/// ## Example
///
/// ```gherkin
/// @smoke @api
/// Feature: User Management
///   As a developer
///   I want to manage users via the API
///
///   Background:
///     Given the base URL is "https://api.example.com"
///
///   Scenario: Fetch user by ID
///     When I make a GET request to "/users/123"
///     Then the response status should be 200
/// ```
public struct GherkinFeature: Sendable, Identifiable, Equatable {
  /// Unique identifier for this feature.
  public let id: UUID

  /// The feature name.
  public let name: String

  /// Optional description providing context.
  public let description: String?

  /// Tags applied to this feature (inherited by scenarios).
  public let tags: [Tag]

  /// Background steps executed before each scenario.
  public let background: GherkinBackground?

  /// The scenarios contained in this feature.
  public let scenarios: [GherkinScenario]

  /// Source location where this feature was defined.
  public let location: GherkinSourceLocation

  /// Creates a new Gherkin feature.
  ///
  /// - Parameters:
  ///   - id: Unique identifier (defaults to new UUID)
  ///   - name: Feature name
  ///   - description: Optional description
  ///   - tags: Tags for filtering
  ///   - background: Optional background steps
  ///   - scenarios: Scenarios in this feature
  ///   - location: Source location
  public init(
    id: UUID = UUID(),
    name: String,
    description: String? = nil,
    tags: [Tag] = [],
    background: GherkinBackground? = nil,
    scenarios: [GherkinScenario] = [],
    location: GherkinSourceLocation = .unknown
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.tags = tags
    self.background = background
    self.scenarios = scenarios
    self.location = location
  }
}

// MARK: - Background

/// Background steps that run before each scenario in a feature.
///
/// Background provides common setup steps shared by all scenarios.
/// It runs before each scenario, not once per feature.
public struct GherkinBackground: Sendable, Equatable {
  /// Optional name for the background.
  public let name: String?

  /// Steps to execute before each scenario.
  public let steps: [GherkinStep]

  /// Source location where this background was defined.
  public let location: GherkinSourceLocation

  /// Creates a new background.
  ///
  /// - Parameters:
  ///   - name: Optional name
  ///   - steps: Steps to execute
  ///   - location: Source location
  public init(
    name: String? = nil,
    steps: [GherkinStep] = [],
    location: GherkinSourceLocation = .unknown
  ) {
    self.name = name
    self.steps = steps
    self.location = location
  }
}

// MARK: - Scenario

/// A Gherkin scenario - either a regular scenario or a scenario outline.
public enum GherkinScenario: Sendable, Identifiable, Equatable {
  /// A regular scenario with fixed steps.
  case scenario(ScenarioDefinition)

  /// A scenario outline with parameterized steps and examples.
  case outline(ScenarioOutlineDefinition)

  /// Unique identifier for this scenario.
  public var id: UUID {
    switch self {
    case .scenario(let def): return def.id
    case .outline(let def): return def.id
    }
  }

  /// The scenario name.
  public var name: String {
    switch self {
    case .scenario(let def): return def.name
    case .outline(let def): return def.name
    }
  }

  /// Tags applied to this scenario.
  public var tags: [Tag] {
    switch self {
    case .scenario(let def): return def.tags
    case .outline(let def): return def.tags
    }
  }

  /// The steps in this scenario.
  public var steps: [GherkinStep] {
    switch self {
    case .scenario(let def): return def.steps
    case .outline(let def): return def.steps
    }
  }

  /// Source location where this scenario was defined.
  public var location: GherkinSourceLocation {
    switch self {
    case .scenario(let def): return def.location
    case .outline(let def): return def.location
    }
  }
}

// MARK: - Scenario Definition

/// A regular scenario with fixed steps.
public struct ScenarioDefinition: Sendable, Identifiable, Equatable {
  /// Unique identifier.
  public let id: UUID

  /// Scenario name.
  public let name: String

  /// Optional description.
  public let description: String?

  /// Tags for filtering.
  public let tags: [Tag]

  /// Steps in this scenario.
  public let steps: [GherkinStep]

  /// Source location.
  public let location: GherkinSourceLocation

  /// Creates a new scenario definition.
  public init(
    id: UUID = UUID(),
    name: String,
    description: String? = nil,
    tags: [Tag] = [],
    steps: [GherkinStep] = [],
    location: GherkinSourceLocation = .unknown
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.tags = tags
    self.steps = steps
    self.location = location
  }
}

// MARK: - Scenario Outline Definition

/// A parameterized scenario with examples.
///
/// Scenario outlines allow running the same scenario multiple times
/// with different data from an Examples table.
///
/// ## Example
///
/// ```gherkin
/// Scenario Outline: Validate endpoints
///   When I request "<path>"
///   Then the status should be <status>
///
///   Examples:
///     | path       | status |
///     | /users/1   | 200    |
///     | /users/999 | 404    |
/// ```
public struct ScenarioOutlineDefinition: Sendable, Identifiable, Equatable {
  /// Unique identifier.
  public let id: UUID

  /// Scenario outline name.
  public let name: String

  /// Optional description.
  public let description: String?

  /// Tags for filtering.
  public let tags: [Tag]

  /// Steps containing `<placeholder>` variables.
  public let steps: [GherkinStep]

  /// Examples tables providing values for placeholders.
  public let examples: [ExamplesTable]

  /// Source location.
  public let location: GherkinSourceLocation

  /// Creates a new scenario outline definition.
  public init(
    id: UUID = UUID(),
    name: String,
    description: String? = nil,
    tags: [Tag] = [],
    steps: [GherkinStep] = [],
    examples: [ExamplesTable] = [],
    location: GherkinSourceLocation = .unknown
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.tags = tags
    self.steps = steps
    self.examples = examples
    self.location = location
  }

  /// Expands the outline into concrete scenarios using the examples.
  ///
  /// - Returns: Array of expanded scenarios with substituted values
  public func expand() -> [ScenarioDefinition] {
    var expanded: [ScenarioDefinition] = []

    for table in examples {
      for row in table.dataRows {
        let substitutedSteps = steps.map { step in
          step.substituting(placeholders: table.headers, with: row)
        }

        let exampleName = zip(table.headers, row)
          .map { "\($0): \($1)" }
          .joined(separator: ", ")

        expanded.append(
          ScenarioDefinition(
            name: "\(name) [\(exampleName)]",
            description: description,
            tags: tags + table.tags,
            steps: substitutedSteps,
            location: location
          )
        )
      }
    }

    return expanded
  }
}

// MARK: - Examples Table

/// An examples table for scenario outlines.
public struct ExamplesTable: Sendable, Equatable {
  /// Optional name for this examples block.
  public let name: String?

  /// Tags specific to this examples block.
  public let tags: [Tag]

  /// Column headers (placeholder names).
  public let headers: [String]

  /// Data rows (values for each placeholder).
  public let rows: [[String]]

  /// Source location.
  public let location: GherkinSourceLocation

  /// Creates a new examples table.
  public init(
    name: String? = nil,
    tags: [Tag] = [],
    headers: [String] = [],
    rows: [[String]] = [],
    location: GherkinSourceLocation = .unknown
  ) {
    self.name = name
    self.tags = tags
    self.headers = headers
    self.rows = rows
    self.location = location
  }

  /// Data rows excluding headers.
  public var dataRows: [[String]] {
    rows
  }

  /// Converts rows to array of dictionaries keyed by header.
  public func asMaps() -> [[String: String]] {
    rows.map { row in
      Dictionary(uniqueKeysWithValues: zip(headers, row))
    }
  }
}

// MARK: - Step

/// A single Gherkin step (Given, When, Then, And, But).
public struct GherkinStep: Sendable, Equatable {
  /// The step keyword.
  public let keyword: StepKeyword

  /// The step text (without keyword).
  public let text: String

  /// Optional data table attached to this step.
  public let dataTable: DataTable?

  /// Optional doc string attached to this step.
  public let docString: DocString?

  /// Source location.
  public let location: GherkinSourceLocation

  /// Creates a new step.
  public init(
    keyword: StepKeyword,
    text: String,
    dataTable: DataTable? = nil,
    docString: DocString? = nil,
    location: GherkinSourceLocation = .unknown
  ) {
    self.keyword = keyword
    self.text = text
    self.dataTable = dataTable
    self.docString = docString
    self.location = location
  }

  /// Creates a new step with placeholder values substituted.
  ///
  /// - Parameters:
  ///   - placeholders: Placeholder names (without angle brackets)
  ///   - values: Values to substitute
  /// - Returns: New step with substituted text
  public func substituting(placeholders: [String], with values: [String]) -> Self {
    var newText = text
    for (placeholder, value) in zip(placeholders, values) {
      newText = newText.replacingOccurrences(of: "<\(placeholder)>", with: value)
    }

    var newDocString = docString
    if let ds = docString {
      var newContent = ds.content
      for (placeholder, value) in zip(placeholders, values) {
        newContent = newContent.replacingOccurrences(of: "<\(placeholder)>", with: value)
      }
      newDocString = DocString(contentType: ds.contentType, content: newContent)
    }

    return Self(
      keyword: keyword,
      text: newText,
      dataTable: dataTable,
      docString: newDocString,
      location: location
    )
  }
}

// MARK: - Step Keyword

/// Gherkin step keywords.
public enum StepKeyword: String, Sendable, CaseIterable, Equatable {
  case given = "Given"
  case when = "When"
  case then = "Then"
  case and = "And"
  case but = "But"
  case asterisk = "*"

  /// The semantic type of this keyword.
  ///
  /// And/But/Asterisk inherit the type of the preceding step.
  public var semanticType: SemanticStepType? {
    switch self {
    case .given: return .given
    case .when: return .when
    case .then: return .then
    case .and, .but, .asterisk: return nil
    }
  }
}

/// Semantic step types (Given, When, Then).
public enum SemanticStepType: String, Sendable, Equatable {
  case given
  case when
  case then
}

// MARK: - Data Table

/// A data table attached to a step.
///
/// Data tables provide tabular data for steps that need multiple values.
public struct DataTable: Sendable, Equatable {
  /// All rows including header row.
  public let rows: [[String]]

  /// Creates a new data table.
  public init(rows: [[String]]) {
    self.rows = rows
  }

  /// The header row (first row).
  public var headers: [String] {
    rows.first ?? []
  }

  /// Data rows (excluding header).
  public var dataRows: [[String]] {
    Array(rows.dropFirst())
  }

  /// Converts to array of dictionaries keyed by header.
  public func asMaps() -> [[String: String]] {
    let headers = self.headers
    return dataRows.map { row in
      Dictionary(uniqueKeysWithValues: zip(headers, row))
    }
  }

  /// Number of columns.
  public var columnCount: Int {
    rows.first?.count ?? 0
  }

  /// Number of data rows (excluding header).
  public var rowCount: Int {
    max(0, rows.count - 1)
  }
}

// MARK: - Doc String

/// A multi-line string attached to a step.
///
/// Doc strings provide longer text content, often JSON or other data.
public struct DocString: Sendable, Equatable {
  /// Optional content type hint (e.g., "json", "xml").
  public let contentType: String?

  /// The string content.
  public let content: String

  /// Creates a new doc string.
  public init(contentType: String? = nil, content: String) {
    self.contentType = contentType
    self.content = content
  }
}

// MARK: - Gherkin Source Location

/// Source location for Gherkin error reporting.
///
/// Named `GherkinSourceLocation` to avoid conflict with `Testing.SourceLocation`.
public struct GherkinSourceLocation: Sendable, Equatable {
  /// Line number (1-indexed).
  public let line: Int

  /// Column number (1-indexed).
  public let column: Int

  /// Optional file path.
  public let file: String?

  /// Creates a new source location.
  public init(line: Int, column: Int, file: String? = nil) {
    self.line = line
    self.column = column
    self.file = file
  }

  /// Unknown location placeholder.
  public static let unknown = Self(line: 0, column: 0, file: nil)

  /// Human-readable description.
  public var description: String {
    if let file = file {
      return "\(file):\(line):\(column)"
    }
    return "line \(line), column \(column)"
  }
}

// MARK: - Tag

/// A tag for filtering and organizing scenarios.
///
/// Tags allow selecting which scenarios to run based on annotations
/// like `@smoke`, `@regression`, `@wip`, etc.
public struct Tag: Sendable, Hashable, ExpressibleByStringLiteral {
  /// The tag name (including @ prefix).
  public let name: String

  /// Creates a new tag.
  ///
  /// - Parameter name: Tag name (@ prefix added if missing)
  public init(_ name: String) {
    self.name = name.hasPrefix("@") ? name : "@\(name)"
  }

  public init(stringLiteral value: String) {
    self.init(value)
  }

  /// Tag name without @ prefix.
  public var rawName: String {
    String(name.dropFirst())
  }
}

// MARK: - Common Tags

extension Tag {
  /// Smoke test tag.
  public static let smoke: Tag = "@smoke"

  /// Regression test tag.
  public static let regression: Tag = "@regression"

  /// Work in progress tag.
  public static let wip: Tag = "@wip"

  /// Skip tag.
  public static let skip: Tag = "@skip"

  /// Slow test tag.
  public static let slow: Tag = "@slow"

  /// Integration test tag.
  public static let integration: Tag = "@integration"

  /// Unit test tag.
  public static let unit: Tag = "@unit"

  /// API test tag.
  public static let api: Tag = "@api"

  /// Critical test tag.
  public static let critical: Tag = "@critical"
}
