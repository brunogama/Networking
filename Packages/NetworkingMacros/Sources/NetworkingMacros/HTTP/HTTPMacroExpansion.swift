import SwiftSyntax
import SwiftSyntaxMacros

/// Protocol for HTTP method macros that share common expansion logic.
///
/// ## Protocol Design
///
/// This protocol uses Swift's protocol extension pattern to provide
/// default implementation while allowing per-macro configuration:
///
/// 1. **Protocol requirement** (`config`): Each conforming type provides
///    its HTTP method configuration (GET, POST, etc.)
///
/// 2. **Protocol extension** (`sharedExpansion`): Provides the complete
///    10-step expansion workflow using the conformer's config.
///
/// ## Usage
///
/// ```swift
/// public struct GETMacro: PeerMacro, HTTPMacroExpansion {
///   public static let config = HTTPMethodConfig.get
///
///   public static func expansion(...) throws -> [DeclSyntax] {
///     try sharedExpansion(of: node, providingPeersOf: declaration, in: context)
///   }
/// }
/// ```
protocol HTTPMacroExpansion {

  static var config: HTTPMethodConfig { get }
}

extension HTTPMacroExpansion {

  static func sharedExpansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let function = declaration.as(FunctionDeclSyntax.self) else {
      MacroHelpers.emitError(
        "@\(config.method) can only be applied to function declarations",
        id: .httpMethodRequiresFunction,
        node: node,
        context: context
      )
      return []
    }

    // @API owns concrete methods for protocol requirements. Swift macro nodes are
    // detached from their parents, so use the expansion context's lexical stack.
    if belongsToAPIProtocol(in: context) {
      return []
    }

    return try endpointExpansion(
      of: node,
      function: function,
      accessLevel: nil,
      context: context
    )
  }

  static func endpointExpansion(
    of node: AttributeSyntax,
    function: FunctionDeclSyntax,
    accessLevel: APIAccessLevel?,
    context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    // Step 2: Validate async throws
    try MacroHelpers.validateAsyncThrows(function: function, context: context)

    // Step 3: Extract and validate path
    guard
      let path = ArgumentExtractors.extractPath(
        from: node,
        method: config.method,
        context: context
      )
    else {
      return []
    }
    try MacroHelpers.validatePathTemplate(path, context: context)

    return try expandWithHelpers(
      HTTPMacroEndpointInput(
        function: function,
        node: node,
        path: path,
        bodyParameter: function.detectBodyMacro(),
        headers: function.detectHeadersMacro(),
        accessLevel: accessLevel
      ),
      context: context
    )
  }

  private static func belongsToAPIProtocol(
    in context: some MacroExpansionContext
  ) -> Bool {
    context.lexicalContext.contains { lexicalNode in
      guard let protocolDeclaration = lexicalNode.as(ProtocolDeclSyntax.self) else {
        return false
      }
      return protocolDeclaration.attributes.contains { element in
        guard case .attribute(let attribute) = element else { return false }
        return attribute.attributeName.trimmedDescription.split(separator: ".").last == "API"
      }
    }
  }
}
