import SwiftSyntax
import SwiftSyntaxMacros

/// Shared argument extraction helpers for HTTP macros.
///
/// Extracts path, body, query parameters, and headers from macro arguments.
/// These helpers eliminate code duplication across GET, POST, PUT, PATCH, and DELETE macros.
public enum ArgumentExtractors {
  // MARK: - Path Extraction

  /// Extracts the path from the first macro argument.
  ///
  /// Example:
  /// ```swift
  /// @GET("/users/{id}")
  /// // Returns: "/users/{id}"
  /// ```
  ///
  /// - Parameters:
  ///   - node: The attribute syntax node
  ///   - context: The macro expansion context for diagnostics
  /// - Returns: The path string, or nil if not found (emits error)
  public static func extractPath(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> String? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
      let firstArg = arguments.first,
      let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
      let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
    else {
      MacroHelpers.emitError(
        "Macro requires a path argument",
        node: node,
        context: context
      )
      return nil
    }

    return segment.content.text
  }

  // MARK: - Body Parameter Extraction

  /// Extracts the body parameter name from macro arguments.
  ///
  /// Example:
  /// ```swift
  /// @POST("/users", body: "user")
  /// // Returns: "user"
  /// ```
  ///
  /// - Parameters:
  ///   - node: The attribute syntax node
  ///   - context: The macro expansion context (not used for errors)
  /// - Returns: The body parameter name, or nil if not found
  ///
  /// - Note: Does NOT emit error if missing - caller decides based on HTTPMethodConfig.requiresBody
  public static func extractBodyParameter(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> String? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      return nil
    }

    // Find argument labeled "body"
    for argument in arguments {
      if argument.label?.text == "body",
        let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
        let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
      {
        return segment.content.text
      }
    }

    return nil
  }

  // MARK: - Query Parameter Extraction

  /// Extracts query parameters from macro arguments.
  ///
  /// Example:
  /// ```swift
  /// @GET("/users", queryParameters: ["page", "limit"])
  /// // Returns: ["page", "limit"]
  /// ```
  ///
  /// - Parameters:
  ///   - node: The attribute syntax node
  ///   - context: The macro expansion context (not used for errors)
  /// - Returns: Array of query parameter names, or empty array if not found
  public static func extractQueryParameters(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> [String] {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      return []
    }

    for argument in arguments {
      if argument.label?.text == "queryParameters",
        let arrayExpr = argument.expression.as(ArrayExprSyntax.self)
      {
        return arrayExpr.elements.compactMap { element in
          if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self),
            let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
          {
            return segment.content.text
          }
          return nil
        }
      }
    }

    return []
  }

  // MARK: - Header Extraction

  /// Extracts custom headers from the macro attribute.
  ///
  /// Example:
  /// ```swift
  /// @POST("/users", headers: ["Authorization": "Bearer token"])
  /// // Returns: ["Authorization": "Bearer token"]
  /// ```
  ///
  /// - Parameters:
  ///   - node: The attribute syntax node
  ///   - context: The macro expansion context (not used for errors)
  /// - Returns: Dictionary of header names to values, or empty dictionary if not found
  public static func extractHeaders(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> [String: String] {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      return [:]
    }

    // Look for headers argument
    for argument in arguments {
      if argument.label?.text == "headers",
        let dictExpr = argument.expression.as(DictionaryExprSyntax.self)
      {
        return parseHeaderDictionary(dictExpr)
      }
    }

    return [:]
  }

  /// Parses header dictionary from DictionaryExprSyntax.
  private static func parseHeaderDictionary(_ dictExpr: DictionaryExprSyntax) -> [String: String] {
    var headers: [String: String] = [:]

    if case .elements(let elements) = dictExpr.content {
      for element in elements {
        if let pair = parseHeaderElement(element) {
          headers[pair.key] = pair.value
        }
      }
    }

    return headers
  }

  /// Parses a single header key-value pair from dictionary element.
  private static func parseHeaderElement(
    _ element: DictionaryElementSyntax
  ) -> (key: String, value: String)? {
    guard let keyString = element.key.as(StringLiteralExprSyntax.self),
      let keySegment = keyString.segments.first,
      case .stringSegment(let keyContent) = keySegment,
      let valueString = element.value.as(StringLiteralExprSyntax.self),
      let valueSegment = valueString.segments.first,
      case .stringSegment(let valueContent) = valueSegment
    else {
      return nil
    }

    return (key: keyContent.content.text, value: valueContent.content.text)
  }
}
