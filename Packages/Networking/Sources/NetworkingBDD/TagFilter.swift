import NetworkingRuntime
import NetworkingTesting
import Foundation

// MARK: - Tag Filter

/// Filters scenarios based on tag expressions.
///
/// Supports AND, OR, NOT operations and parentheses for complex expressions.
///
/// ## Usage
///
/// ```swift
/// // Simple tag matching
/// let filter = TagFilter.include("@smoke")
///
/// // AND operation (all tags must match)
/// let filter = TagFilter.all(["@smoke", "@api"])
///
/// // OR operation (any tag matches)
/// let filter = TagFilter.any(["@smoke", "@regression"])
///
/// // NOT operation (exclude tags)
/// let filter = TagFilter.exclude("@skip")
///
/// // Complex expression
/// let filter = TagFilter.expression("@smoke and not @slow")
///
/// // Check if scenario matches
/// if filter.matches(scenarioTags) {
///   // Run scenario
/// }
/// ```
public struct TagFilter: Sendable {
  // MARK: - Types

  /// Filter expression type.
  public indirect enum Expression: Sendable {
    /// Include if tag matches.
    case tag(Tag)

    /// Include if all expressions match (AND).
    case and([Self])

    /// Include if any expression matches (OR).
    case or([Self])

    /// Include if expression does not match (NOT).
    case not(Self)

    /// Always matches.
    case any

    /// Never matches.
    case none
  }

  // MARK: - Properties

  private let expression: Expression

  // MARK: - Initialization

  /// Creates a filter with an expression.
  ///
  /// - Parameter expression: The filter expression
  public init(_ expression: Expression) {
    self.expression = expression
  }

  // MARK: - Factory Methods

  /// Creates a filter that matches any scenario (no filtering).
  public static var all: Self {
    Self(.any)
  }

  /// Creates a filter that matches no scenario.
  public static var none: Self {
    Self(.none)
  }

  /// Creates a filter that includes scenarios with the given tag.
  ///
  /// - Parameter tag: Tag to include
  /// - Returns: Tag filter
  public static func include(_ tag: Tag) -> Self {
    Self(.tag(tag))
  }

  /// Creates a filter that includes scenarios with the given tag.
  ///
  /// - Parameter tagName: Tag name to include
  /// - Returns: Tag filter
  public static func include(_ tagName: String) -> Self {
    Self(.tag(Tag(tagName)))
  }

  /// Creates a filter that excludes scenarios with the given tag.
  ///
  /// - Parameter tag: Tag to exclude
  /// - Returns: Tag filter
  public static func exclude(_ tag: Tag) -> Self {
    Self(.not(.tag(tag)))
  }

  /// Creates a filter that excludes scenarios with the given tag.
  ///
  /// - Parameter tagName: Tag name to exclude
  /// - Returns: Tag filter
  public static func exclude(_ tagName: String) -> Self {
    Self(.not(.tag(Tag(tagName))))
  }

  /// Creates a filter that requires all given tags (AND).
  ///
  /// - Parameter tags: Tags that must all match
  /// - Returns: Tag filter
  public static func all(_ tags: [Tag]) -> Self {
    Self(.and(tags.map { .tag($0) }))
  }

  /// Creates a filter that requires all given tags (AND).
  ///
  /// - Parameter tagNames: Tag names that must all match
  /// - Returns: Tag filter
  public static func all(_ tagNames: [String]) -> Self {
    Self(.and(tagNames.map { .tag(Tag($0)) }))
  }

  /// Creates a filter that matches any of the given tags (OR).
  ///
  /// - Parameter tags: Tags where any must match
  /// - Returns: Tag filter
  public static func any(_ tags: [Tag]) -> Self {
    Self(.or(tags.map { .tag($0) }))
  }

  /// Creates a filter that matches any of the given tags (OR).
  ///
  /// - Parameter tagNames: Tag names where any must match
  /// - Returns: Tag filter
  public static func any(_ tagNames: [String]) -> Self {
    Self(.or(tagNames.map { .tag(Tag($0)) }))
  }

  /// Creates a filter from a tag expression string.
  ///
  /// Supports:
  /// - `@tag` - simple tag match
  /// - `@tag1 and @tag2` - both must match
  /// - `@tag1 or @tag2` - either must match
  /// - `not @tag` - must not match
  /// - Parentheses for grouping
  ///
  /// - Parameter expressionString: Tag expression string
  /// - Returns: Tag filter (or .all if expression is empty/invalid)
  public static func expression(_ expressionString: String) -> Self {
    var parser = TagExpressionParser()
    if let expr = parser.parse(expressionString) {
      return Self(expr)
    }
    return .all
  }

  // MARK: - Matching

  /// Checks if the given tags match this filter.
  ///
  /// - Parameter tags: Tags to check
  /// - Returns: True if tags match the filter
  public func matches(_ tags: [Tag]) -> Bool {
    evaluate(expression, against: Set(tags.map { $0.name }))
  }

  /// Checks if the given tag names match this filter.
  ///
  /// - Parameter tagNames: Tag names to check
  /// - Returns: True if tags match the filter
  public func matches(_ tagNames: [String]) -> Bool {
    let normalizedTags = Set(tagNames.map { $0.hasPrefix("@") ? $0 : "@\($0)" })
    return evaluate(expression, against: normalizedTags)
  }

  // MARK: - Private Methods

  private func evaluate(_ expr: Expression, against tags: Set<String>) -> Bool {
    switch expr {
    case .tag(let tag):
      return tags.contains(tag.name)

    case .and(let expressions):
      return expressions.allSatisfy { evaluate($0, against: tags) }

    case .or(let expressions):
      return expressions.contains { evaluate($0, against: tags) }

    case .not(let expression):
      return !evaluate(expression, against: tags)

    case .any:
      return true

    case .none:
      return false
    }
  }
}

// MARK: - Combinators

extension TagFilter {
  /// Combines this filter with another using AND.
  ///
  /// - Parameter other: Other filter
  /// - Returns: Combined filter
  public func and(_ other: TagFilter) -> TagFilter {
    TagFilter(.and([expression, other.expression]))
  }

  /// Combines this filter with another using OR.
  ///
  /// - Parameter other: Other filter
  /// - Returns: Combined filter
  public func or(_ other: TagFilter) -> TagFilter {
    TagFilter(.or([expression, other.expression]))
  }

  /// Negates this filter.
  ///
  /// - Returns: Negated filter
  public func negated() -> TagFilter {
    TagFilter(.not(expression))
  }
}

// MARK: - Operators

extension TagFilter {
  /// AND operator for combining filters.
  public static func && (lhs: TagFilter, rhs: TagFilter) -> TagFilter {
    lhs.and(rhs)
  }

  /// OR operator for combining filters.
  public static func || (lhs: TagFilter, rhs: TagFilter) -> TagFilter {
    lhs.or(rhs)
  }

  /// NOT operator for negating a filter.
  public static prefix func ! (filter: TagFilter) -> TagFilter {
    filter.negated()
  }
}

// MARK: - Tag Expression Parser

/// Parses tag expression strings into Expression objects.
private struct TagExpressionParser {
  private var tokens: [String] = []
  private var index: Int = 0

  mutating func parse(_ input: String) -> TagFilter.Expression? {
    tokens = tokenize(input)
    index = 0
    guard !tokens.isEmpty else { return nil }
    return parseExpression()
  }

  private func tokenize(_ input: String) -> [String] {
    var tokens: [String] = []
    var current = ""
    let chars = Array(input.lowercased())
    var i = 0

    while i < chars.count {
      let char = chars[i]

      if char == "@" {
        if !current.isEmpty {
          tokens.append(current)
          current = ""
        }
        // Read tag name
        var tag = "@"
        i += 1
        while i < chars.count
          && (chars[i].isLetter || chars[i].isNumber || chars[i] == "-" || chars[i] == "_")
        {
          tag.append(chars[i])
          i += 1
        }
        tokens.append(tag)
        continue
      }

      if char == "(" {
        if !current.isEmpty {
          tokens.append(current)
          current = ""
        }
        tokens.append("(")
        i += 1
        continue
      }

      if char == ")" {
        if !current.isEmpty {
          tokens.append(current)
          current = ""
        }
        tokens.append(")")
        i += 1
        continue
      }

      if char.isWhitespace {
        if !current.isEmpty {
          tokens.append(current)
          current = ""
        }
        i += 1
        continue
      }

      current.append(char)
      i += 1
    }

    if !current.isEmpty {
      tokens.append(current)
    }

    return tokens
  }

  private mutating func parseExpression() -> TagFilter.Expression? {
    parseOr()
  }

  private mutating func parseOr() -> TagFilter.Expression? {
    guard var left = parseAnd() else { return nil }

    while index < tokens.count && tokens[index] == "or" {
      index += 1
      guard let right = parseAnd() else { return nil }
      left = .or([left, right])
    }

    return left
  }

  private mutating func parseAnd() -> TagFilter.Expression? {
    guard var left = parseNot() else { return nil }

    while index < tokens.count && tokens[index] == "and" {
      index += 1
      guard let right = parseNot() else { return nil }
      left = .and([left, right])
    }

    return left
  }

  private mutating func parseNot() -> TagFilter.Expression? {
    if index < tokens.count && tokens[index] == "not" {
      index += 1
      guard let expr = parsePrimary() else { return nil }
      return .not(expr)
    }
    return parsePrimary()
  }

  private mutating func parsePrimary() -> TagFilter.Expression? {
    guard index < tokens.count else { return nil }

    let token = tokens[index]

    if token == "(" {
      index += 1
      let expr = parseExpression()
      if index < tokens.count && tokens[index] == ")" {
        index += 1
      }
      return expr
    }

    if token.hasPrefix("@") {
      index += 1
      return .tag(Tag(token))
    }

    return nil
  }
}

// MARK: - ExpressibleByStringLiteral

extension TagFilter: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self = TagFilter.expression(value)
  }
}
