import SwiftSyntax
import SwiftSyntaxMacros

/// Macro implementation for @DELETE HTTP method.
///
/// Generates code for DELETE requests (typically for resource deletion).
///
/// Example:
/// ```swift
/// @DELETE("/users/{id}")
/// func deleteUser(id: String) async throws
/// ```
public struct DELETEMacro: PeerMacro, HTTPMacroExpansion {
  static let config = HTTPMethodConfig.delete

  /// Expands an endpoint using the shared HTTP request implementation.
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try sharedExpansion(of: node, providingPeersOf: declaration, in: context)
  }
}
