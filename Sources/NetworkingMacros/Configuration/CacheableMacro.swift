import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
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
        message: MacroDiagnostic.cacheableRequiresProtocol
      )
      context.diagnose(diagnostic)
      return []
    }

    // Extract arguments
    let duration = extractDuration(from: node) ?? "300"
    let policy = extractPolicy(from: node) ?? "standard"
    let protocolName = protocolDecl.name.text

    // Generate extension with cacheConfiguration
    let extensionCode: DeclSyntax = """
      extension \(raw: protocolName) {
        static var cacheConfiguration: CacheConfiguration {
          CacheConfiguration(
            duration: .ttl(\(raw: duration).0),
            policy: .\(raw: policy)
          )
        }
      }
      """

    return [extensionCode]
  }

  private static func extractDuration(from node: AttributeSyntax) -> String? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      return nil
    }

    for argument in arguments {
      if argument.label?.text == "duration",
        let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self)
      {
        return intLiteral.literal.text
      }
    }
    return nil
  }

  private static func extractPolicy(from node: AttributeSyntax) -> String? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      return nil
    }

    for argument in arguments {
      if argument.label?.text == "policy",
        let memberAccess = argument.expression.as(MemberAccessExprSyntax.self)
      {
        return memberAccess.declName.baseName.text
      }
    }
    return nil
  }
}

// MARK: - Diagnostics

enum MacroDiagnostic: String, DiagnosticMessage {
  case cacheableRequiresProtocol
  case measuredRequiresFunction

  var message: String {
    switch self {
    case .cacheableRequiresProtocol:
      return "@Cacheable can only be applied to protocols"
    case .measuredRequiresFunction:
      return "@Measured can only be applied to functions"
    }
  }

  var diagnosticID: MessageID {
    MessageID(domain: "NetworkingMacros", id: rawValue)
  }

  var severity: DiagnosticSeverity { .error }
}
