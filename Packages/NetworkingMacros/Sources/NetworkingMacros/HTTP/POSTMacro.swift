import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

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
  public static let config = HTTPMethodConfig.post

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try sharedExpansion(of: node, providingPeersOf: declaration, in: context)
  }
}
