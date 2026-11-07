import SwiftSyntax
import SwiftSyntaxMacros

/// Shared argument extraction helpers for HTTP macros.
///
/// Extracts path, body, query parameters, and headers from macro arguments.
/// These helpers eliminate code duplication across GET, POST, PUT, PATCH, and DELETE macros.
enum ArgumentExtractors {
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
  ///   - method: The HTTP method name for error messages (e.g., "GET", "POST")
  ///   - context: The macro expansion context for diagnostics
  /// - Returns: The path string, or nil if not found (emits error)
  static func extractPath(
    from node: AttributeSyntax,
    method: String,
    context: some MacroExpansionContext
  ) -> String? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
      let firstArg = arguments.first,
      let path = BoundaryExpressionParser.string(from: firstArg.expression)
    else {
      MacroHelpers.emitError(
        "@\(method) requires a path argument",
        id: .missingPath,
        node: node,
        context: context
      )
      return nil
    }

    return path
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
  static func extractQueryParameters(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> [String] {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      return []
    }

    for argument in arguments {
      if argument.label?.text == "queryParameters" || argument.label?.text == "query",
        let queryParameters = BoundaryExpressionParser.arrayOfStrings(from: argument.expression)
      {
        return queryParameters
      }
    }

    return []
  }

}
