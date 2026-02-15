import MacroTemplateKit
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Generates a static cacheConfiguration property for API protocols.
///
/// Example:
/// ```swift
/// @Cacheable(duration: 300)
/// protocol UserAPI {
///   func getUser(id: String) async throws -> User
/// }
/// ```
///
/// Expands to:
/// ```swift
/// extension UserAPI {
///   static var cacheConfiguration: CacheConfiguration {
///     CacheConfiguration(
///       duration: .ttl(300),
///       policy: .standard
///     )
///   }
/// }
/// ```
public struct CacheableMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Verify applied to protocol
    guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
      let diagnostic = Diagnostic(
        node: Syntax(node),
        message: ConfigurationMacroDiagnostic.cacheableRequiresProtocol
      )
      context.diagnose(diagnostic)
      return []
    }

    // Extract arguments using shared helpers
    let duration = MacroHelpers.extractIntegerValue(labeled: "duration", from: node)
      ?? "300"
    let policy = MacroHelpers.extractMemberValue(labeled: "policy", from: node)
      ?? "standard"
    let protocolName = protocolDecl.name.text

    // Generate extension with cacheConfiguration using string interpolation
    // Note: Template algebra infrastructure available via MacroTemplateKit for future enhancement
    let extensionCode: DeclSyntax = """
      extension \(raw: protocolName) {
        static var cacheConfiguration: CacheConfiguration {
          CacheConfiguration(
            duration: .ttl(\(raw: duration)),
            policy: .\(raw: policy)
          )
        }
      }
      """

    return [extensionCode]
  }
}
