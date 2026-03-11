import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

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
  /// Configuration for this HTTP method (GET, POST, etc.)
  ///
  /// This is the ONLY requirement conformers must satisfy.
  /// The protocol extension reads this property to customize behavior.
  static var config: HTTPMethodConfig { get }
}

extension HTTPMacroExpansion {
  /// Shared expansion implementation for all HTTP method macros.
  ///
  /// This default implementation in the protocol extension provides
  /// the complete 10-step expansion workflow. Conforming types call
  /// this method from their `expansion(of:providingPeersOf:in:)` method.
  ///
  /// - Parameters:
  ///   - node: The attribute syntax node
  ///   - declaration: The function declaration being annotated
  ///   - context: The macro expansion context
  /// - Returns: Array of generated declarations
  /// - Throws: Macro expansion errors
  static func sharedExpansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Step 1: Validate function declaration
    guard let function = declaration.as(FunctionDeclSyntax.self) else {
      MacroHelpers.emitError(
        "@\(config.method) can only be applied to function declarations",
        node: node,
        context: context
      )
      return []
    }

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

    // Step 4: Detect syntax style
    let usesOldSyntax = function.usesOldMacroSyntax()
    let newBodyParam = function.detectBodyMacro()
    let newHeaders = function.detectHeadersMacro()

    // Step 5: Check for syntax mixing
    if usesOldSyntax && (newBodyParam != nil || !newHeaders.isEmpty) {
      MacroHelpers.emitError(
        "Cannot mix old and new syntax for @\(config.method)",
        node: node,
        context: context
      )
      return []
    }

    // Step 6: Emit deprecation warning for old syntax
    if usesOldSyntax {
      MacroHelpers.emitWarning(
        "Old syntax is deprecated. Use @Body and @Headers macros instead.",
        node: Syntax(node),
        context: context
      )
    }

    // Steps 7-10: Delegate to helper methods
    return try expandWithHelpers(
      function: function,
      node: node,
      path: path,
      usesOldSyntax: usesOldSyntax,
      newBodyParam: newBodyParam,
      newHeaders: newHeaders,
      context: context
    )
  }
}
