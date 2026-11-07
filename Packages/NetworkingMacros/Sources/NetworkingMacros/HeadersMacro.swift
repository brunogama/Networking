import SwiftSyntax
import SwiftSyntaxMacros

/// Validates method-level headers that the HTTP method macro applies to its request.
public struct HeadersMacro: PeerMacro {
  /// Diagnoses invalid header dictionaries without adding peer declarations.
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let function = declaration.as(FunctionDeclSyntax.self) else {
      MacroHelpers.emitError(
        "@Headers can only be applied to functions",
        id: .headersRequiresFunction,
        node: node,
        context: context
      )
      return []
    }
    guard let headers = HeaderMacroParser.parseHeaders(from: node) else {
      MacroHelpers.emitError(
        "@Headers requires a dictionary of .literal or .parameter values",
        id: .invalidHeaders,
        node: node,
        context: context
      )
      return []
    }
    let parameters = MacroHelpers.extractParameterNames(from: function)
    for header in headers {
      validate(header, parameters: parameters, node: node, context: context)
    }
    return []
  }

  private static func validate(
    _ header: ParsedHeader,
    parameters: [String],
    node: AttributeSyntax,
    context: some MacroExpansionContext
  ) {
    validateName(header.name, node: node, context: context)
    switch header.valueSource {
    case .literal(let value):
      if value.unicodeScalars.contains(where: { $0 == "\r" || $0 == "\n" }) {
        MacroHelpers.emitError(
          "Header values must contain no CR or LF",
          id: .invalidHeaderValue,
          node: node,
          context: context
        )
      }
    case .parameter(let name):
      if !parameters.contains(name) {
        MacroHelpers.emitError(
          "Header parameter '\(name)' was not found",
          id: .unknownHeaderParameter,
          node: node,
          context: context
        )
      }
    }
  }

  private static func validateName(
    _ name: String,
    node: AttributeSyntax,
    context: some MacroExpansionContext
  ) {
    guard name.isEmpty || name.unicodeScalars.contains(where: { $0 == "\r" || $0 == "\n" }) else {
      return
    }
    MacroHelpers.emitError(
      "Header names must be nonempty and contain no CR or LF",
      id: .invalidHeaderName,
      node: node,
      context: context
    )
  }
}
