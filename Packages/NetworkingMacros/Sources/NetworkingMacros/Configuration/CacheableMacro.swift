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
    let durationString = MacroHelpers.extractIntegerValue(labeled: "duration", from: node)
      ?? "300"
    let policy = MacroHelpers.extractMemberValue(labeled: "policy", from: node)
      ?? "standard"
    let protocolName = protocolDecl.name.text

    // Convert duration string to integer for Template.literal()
    let durationValue = Int(durationString) ?? 300

    // Build CacheConfiguration using Template algebra
    let ttlTemplate: Template<Void> = .functionCall(
      function: "ttl",
      arguments: [(label: nil, value: .literal(.integer(durationValue)))]
    )

    let policyTemplate: Template<Void> = .propertyAccess(
      base: .literal(.nil),
      property: policy
    )

    let cacheConfigTemplate: Template<Void> = .functionCall(
      function: "CacheConfiguration",
      arguments: [
        (label: "duration", value: ttlTemplate),
        (label: "policy", value: policyTemplate)
      ]
    )

    // Render Template to ExprSyntax
    let cacheConfigExpr = Renderer.render(cacheConfigTemplate)

    // Build extension using SwiftSyntax result builders
    let extensionCode: DeclSyntax = """
      extension \(raw: protocolName) {
        static var cacheConfiguration: CacheConfiguration {
          \(cacheConfigExpr)
        }
      }
      """

    return [extensionCode]
  }
}
