import Foundation

/// Parser for REST API path templates with parameter substitution.
///
/// Handles path templates like "/users/{id}/posts/{postId}" and generates
/// Swift string interpolation code for runtime path construction.
///
/// Example:
/// ```swift
/// let parser = PathTemplateParser(template: "/users/{id}/posts/{postId}")
/// let params = parser.extractParameters() // ["id", "postId"]
/// try parser.validate()
/// let code = parser.generatePathSubstitution() // "\"/users/\\(id)/posts/\\(postId)\""
/// ```
struct PathTemplateParser {
  /// The path template to parse (e.g., "/users/{id}").
  let template: String

  /// Regular expression pattern for matching path parameters.
  ///
  /// Matches: `{parameterName}` where parameterName is a valid Swift identifier
  private static let parameterPattern = #"\{(\w+)\}"#

  // MARK: - Parameter Extraction

  /// Extracts all parameter names from the path template.
  ///
  /// Given a template like "/users/{id}/posts/{postId}", returns ["id", "postId"].
  ///
  /// - Returns: Array of parameter names found in {braces}, in order of appearance
  func extractParameters() -> [String] {
    guard let regex = try? NSRegularExpression(pattern: Self.parameterPattern) else {
      return []
    }

    let nsString = template as NSString
    let matches = regex.matches(
      in: template,
      range: NSRange(location: 0, length: nsString.length)
    )

    return matches.compactMap { match in
      guard match.numberOfRanges > 1 else { return nil }
      let range = match.range(at: 1)
      return nsString.substring(with: range)
    }
  }

  // MARK: - Validation

  /// Validates the path template syntax.
  ///
  /// Checks:
  /// - Balanced braces
  /// - Valid parameter names (Swift identifiers)
  /// - No empty parameter names
  /// - No invalid characters in parameter names
  ///
  /// - Throws: `MacroExpansionError.invalidPathTemplate` if validation fails
  func validate() throws {
    // Check for balanced braces
    try validateBalancedBraces()

    // Validate each parameter
    try validateParameterSyntax()

    // Validate path starts with /
    guard template.hasPrefix("/") else {
      throw MacroExpansionError.invalidPathTemplate(
        template,
        suggestion: "Path must start with '/'"
      )
    }
  }

  /// Validates that braces are balanced.
  private func validateBalancedBraces() throws {
    let openBraces = template.filter { $0 == "{" }.count
    let closeBraces = template.filter { $0 == "}" }.count

    guard openBraces == closeBraces else {
      let suggestion =
        openBraces > closeBraces
        ? "Missing \(openBraces - closeBraces) closing brace(s) '}'"
        : "Missing \(closeBraces - openBraces) opening brace(s) '{'"
      throw MacroExpansionError.invalidPathTemplate(template, suggestion: suggestion)
    }
  }

  /// Validates parameter name syntax.
  private func validateParameterSyntax() throws {
    guard let regex = try? NSRegularExpression(pattern: Self.parameterPattern) else {
      return
    }

    let nsString = template as NSString
    let matches = regex.matches(
      in: template,
      range: NSRange(location: 0, length: nsString.length)
    )

    for match in matches {
      guard match.numberOfRanges > 1 else { continue }
      let range = match.range(at: 1)
      let paramName = nsString.substring(with: range)

      // Check for empty parameter name
      if paramName.isEmpty {
        throw MacroExpansionError.invalidPathTemplate(
          template,
          suggestion: "Empty parameter name found: {}"
        )
      }

      // Check for valid Swift identifier characters
      if !isValidSwiftIdentifier(paramName) {
        throw MacroExpansionError.invalidPathTemplate(
          template,
          suggestion: "Parameter '\(paramName)' is not a valid Swift identifier"
        )
      }
    }

    // Check for unmatched braces (braces without parameter names)
    try validateNoUnmatchedBraces()
  }

  /// Validates no standalone braces exist.
  private func validateNoUnmatchedBraces() throws {
    // Pattern to find any brace not part of a valid parameter
    let invalidBracePattern = #"\{(?!\w+\})|(?<!\{\w+)\}"#
    guard let regex = try? NSRegularExpression(pattern: invalidBracePattern) else {
      return
    }

    let nsString = template as NSString
    let matches = regex.matches(
      in: template,
      range: NSRange(location: 0, length: nsString.length)
    )

    if !matches.isEmpty {
      throw MacroExpansionError.invalidPathTemplate(
        template,
        suggestion: "Malformed braces found - use {parameterName} syntax"
      )
    }
  }

  /// Checks if a string is a valid Swift identifier.
  ///
  /// Valid identifiers:
  /// - Start with letter or underscore
  /// - Contain only letters, numbers, underscores
  private func isValidSwiftIdentifier(_ name: String) -> Bool {
    guard !name.isEmpty else { return false }

    let firstChar = name.first!
    guard firstChar.isLetter || firstChar == "_" else { return false }

    return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }

  // MARK: - Code Generation

  /// Generates Swift string interpolation code for the path template.
  ///
  /// Converts a path template into Swift code that can be embedded in generated functions.
  ///
  /// Examples:
  /// - Input: "/users/{id}"
  /// - Output: "\"/users/\\(id)\""
  ///
  /// - Input: "/users/{userId}/posts/{postId}"
  /// - Output: "\"/users/\\(userId)/posts/\\(postId)\""
  ///
  /// - Returns: Swift string literal with interpolation
  func generatePathSubstitution() -> String {
    var result = template

    // Replace each {param} with \(param)
    let parameters = extractParameters()
    for param in parameters {
      result = result.replacingOccurrences(of: "{\(param)}", with: "\\(\(param))")
    }

    // Wrap in quotes
    return "\"\(result)\""
  }

  /// Generates code with validation for parameter existence.
  ///
  /// For optional parameters, generates guard statements to unwrap them.
  ///
  /// Example for optional parameter:
  /// ```swift
  /// guard let id = id else {
  ///   throw APIClientError.invalidRequest("Missing required parameter: id")
  /// }
  /// ```
  func generateValidatedPathSubstitution(
    parameters: [(name: String, isOptional: Bool)]
  ) -> (guards: [String], path: String) {
    var guards: [String] = []

    for param in parameters where !param.isOptional {
      let guardStatement = """
        guard let \(param.name) = \(param.name) else {
          throw APIClientError.invalidRequest("Missing required parameter: \(param.name)")
        }
        """
      guards.append(guardStatement)
    }

    let pathCode = generatePathSubstitution()
    return (guards: guards, path: pathCode)
  }
}

// Note: MacroExpansionError is defined in MacroHelpers.swift
