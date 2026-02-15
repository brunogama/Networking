import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

/// Macro implementation for @PUT HTTP method.
///
/// Generates code for PUT requests with request body support.
///
/// Example:
/// ```swift
/// @PUT("/users/{id}")
/// @Body("user")
/// func updateUser(id: String, user: User) async throws -> User
/// ```
public struct PUTMacro: PeerMacro, HTTPMacroExpansion {
  public static let config = HTTPMethodConfig.put

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    try sharedExpansion(of: node, providingPeersOf: declaration, in: context)
  }
}
