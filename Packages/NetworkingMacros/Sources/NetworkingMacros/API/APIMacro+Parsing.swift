import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

struct APIExpansionInput {
  let protocolDeclaration: ProtocolDeclSyntax
  let baseURL: String
  let accessLevel: String?
}

extension APIMacro {
  static func expansionInput(
    node: AttributeSyntax,
    declaration: some DeclSyntaxProtocol,
    context: some MacroExpansionContext
  ) -> APIExpansionInput? {
    guard let protocolDeclaration = declaration.as(ProtocolDeclSyntax.self) else {
      diagnose(
        "@API can only be applied to protocols",
        id: "invalidAPIUsage",
        node: node,
        context: context
      )
      return nil
    }
    guard let baseURL = extractBaseURL(from: node, context: context) else {
      return nil
    }
    guard !baseURL.isEmpty else {
      diagnose("Base URL cannot be empty", id: "emptyBaseURL", node: node, context: context)
      return nil
    }
    return APIExpansionInput(
      protocolDeclaration: protocolDeclaration,
      baseURL: baseURL,
      accessLevel: declaredAccessLevel(of: protocolDeclaration)
    )
  }

  private static func extractBaseURL(
    from attribute: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> String? {
    guard let arguments = attribute.arguments,
      case .argumentList(let list) = arguments,
      let firstArgument = list.first
    else {
      diagnose(
        "@API requires a baseURL argument",
        id: "missingBaseURL",
        node: attribute,
        context: context
      )
      return nil
    }

    guard let baseURL = BoundaryExpressionParser.string(from: firstArgument.expression) else {
      diagnose(
        "Base URL must use a typed base URL expression",
        id: "invalidBaseURL",
        node: attribute,
        context: context
      )
      return nil
    }
    return baseURL
  }

  private static func diagnose(
    _ message: String,
    id: String,
    node: some SyntaxProtocol,
    context: some MacroExpansionContext
  ) {
    context.diagnose(
      Diagnostic(
        node: Syntax(node),
        message: SimpleDiagnosticMessage(
          message: message,
          diagnosticID: MessageID(domain: "Networking", id: id),
          severity: .error
        )
      )
    )
  }
}
