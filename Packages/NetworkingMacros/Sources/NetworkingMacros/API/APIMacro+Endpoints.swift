import SwiftSyntax
import SwiftSyntaxMacros

extension APIMacro {
  private static var endpointMacros: [String: any HTTPMacroExpansion.Type] {
    [
      "GET": GETMacro.self,
      "POST": POSTMacro.self,
      "PUT": PUTMacro.self,
      "PATCH": PATCHMacro.self,
      "DELETE": DELETEMacro.self,
    ]
  }

  static func endpointImplementations(
    in protocolDeclaration: ProtocolDeclSyntax,
    accessLevel: String?,
    context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    var implementations: [DeclSyntax] = []
    for member in protocolDeclaration.memberBlock.members {
      guard let function = member.decl.as(FunctionDeclSyntax.self) else {
        MacroHelpers.emitError(
          "@API protocols may only contain endpoint methods",
          node: member.decl,
          context: context
        )
        continue
      }
      implementations.append(
        contentsOf: try endpointImplementation(
          for: function,
          accessLevel: accessLevel,
          context: context
        )
      )
    }
    return implementations
  }

  private static func endpointImplementation(
    for function: FunctionDeclSyntax,
    accessLevel: String?,
    context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try MacroHelpers.validateSingleHTTPMethod(on: function, context: context)
    guard let (name, attribute) = endpointAttribute(on: function) else {
      MacroHelpers.emitError(
        "Method '\(function.name.text)' requires an HTTP method macro",
        node: function,
        context: context
      )
      return []
    }
    guard let macro = endpointMacros[name] else {
      return []
    }
    return try macro.endpointExpansion(
      of: attribute,
      function: function,
      accessLevel: accessLevel,
      context: context
    )
  }

  private static func endpointAttribute(
    on function: FunctionDeclSyntax
  ) -> (name: String, attribute: AttributeSyntax)? {
    for element in function.attributes {
      guard case .attribute(let attribute) = element else { continue }
      let name = attribute.attributeName.trimmedDescription.split(separator: ".").last.map(
        String.init
      )
      if let name, endpointMacros[name] != nil {
        return (name, attribute)
      }
    }
    return nil
  }
}
