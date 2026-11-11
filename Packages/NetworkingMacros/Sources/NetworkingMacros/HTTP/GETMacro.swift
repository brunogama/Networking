import SwiftSyntax
import SwiftSyntaxMacros

/// Macro implementation for @GET HTTP method.
///
/// Generates code for GET requests (read operations).
///
/// Example:
/// ```swift
/// @GET("/users/{id}")
/// func getUser(id: String) async throws -> User
/// ```
public struct GETMacro: PeerMacro, HTTPMacroExpansion {
  static let config = HTTPMethodConfig.get

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try sharedExpansion(of: node, providingPeersOf: declaration, in: context)
  }
}
