import SwiftSyntax
import SwiftSyntaxMacros

/// Shared argument extraction helpers for HTTP macros.
///
/// Extracts path, body, query parameters, and headers from macro arguments.
/// These helpers eliminate code duplication across GET, POST, PUT, PATCH, and DELETE macros.
enum ArgumentExtractors {
  // MARK: - Path Extraction

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
