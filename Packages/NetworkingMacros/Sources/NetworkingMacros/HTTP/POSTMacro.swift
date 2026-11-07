import SwiftSyntax
import SwiftSyntaxMacros

/// Macro implementation for @POST HTTP method.
///
/// Generates code for POST requests with request body support.
///
/// Example:
/// ```swift
/// @POST("/users")
/// @Body("user")
/// func createUser(user: User) async throws -> User
/// ```
public struct POSTMacro: PeerMacro, HTTPMacroExpansion {
  static let config = HTTPMethodConfig.post

  /// Expands an endpoint using the shared HTTP request implementation.
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try sharedExpansion(of: node, providingPeersOf: declaration, in: context)
  }
}
