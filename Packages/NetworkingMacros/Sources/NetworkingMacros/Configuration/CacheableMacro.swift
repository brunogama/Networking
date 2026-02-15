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
    let durationValue = Int(durationString) ?? 300

    // Build extension with cache configuration property
    let extensionDecl = buildCacheConfigurationExtension(
      protocolName: protocolName,
      duration: durationValue,
      policy: policy
    )

    return [Renderer.render(extensionDecl)]
  }

  private static func buildCacheConfigurationExtension(
    protocolName: String,
    duration: Int,
    policy: String
  ) -> Declaration<Void> {
    // Build CacheConfiguration call template
    let cacheConfigTemplate = Template<Void>.functionCall(
      function: "CacheConfiguration",
      arguments: [
        (label: "duration", value: .functionCall(
          function: "ttl",
          arguments: [(label: nil, value: .literal(.integer(duration)))]
        )),
        (label: "policy", value: .propertyAccess(
          base: .literal(.nil),
          property: policy
        ))
      ]
    )

    // Build static computed property
    let computedProp = ComputedPropertySignature<Void>(
      name: "cacheConfiguration",
      type: "CacheConfiguration",
      isStatic: true,
      getter: [.returnStatement(cacheConfigTemplate)]
    )

    // Build extension declaration
    return .extensionDecl(
      ExtensionSignature(
        typeName: protocolName,
        members: [.computedProperty(computedProp)]
      )
    )
  }
}
