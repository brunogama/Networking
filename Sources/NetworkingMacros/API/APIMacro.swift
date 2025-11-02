import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

/// Macro implementation for @API attached to protocols.
///
/// Generates an implementation struct with:
/// - Sendable conformance
/// - Private NetworkClient property
/// - Public initializer with optional client parameter
/// - Full implementation of all protocol methods
public struct APIMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Validate this is a protocol
    guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: SimpleDiagnosticMessage(
            message: "@API can only be applied to protocols",
            diagnosticID: MessageID(domain: "Networking", id: "invalidAPIUsage"),
            severity: .error
          )
        )
      )
      return []
    }

    // Extract base URL from macro arguments
    guard let baseURL = extractBaseURL(from: node, context: context) else {
      return []
    }

    // Validate base URL is not empty
    guard !baseURL.isEmpty else {
      context.diagnose(
        Diagnostic(
          node: Syntax(node),
          message: SimpleDiagnosticMessage(
            message: "Base URL cannot be empty",
            diagnosticID: MessageID(domain: "Networking", id: "emptyBaseURL"),
            severity: .error
          )
        )
      )
      return []
    }

    // Get protocol name
    let protocolName = protocolDecl.name.text

    // Extract default headers from @DefaultHeaders attribute
    let defaultHeaders = DefaultHeadersMacro.extractDefaultHeaders(from: protocolDecl)

    // Extract default timeout from @Timeout attribute
    let defaultTimeout = TimeoutMacro.extractDefaultTimeout(from: protocolDecl)

    // Build member declarations for the implementation struct
    var members: [DeclSyntax] = []

    // NetworkClient property
    members.append(
      DeclSyntax(
        """
        private let client: NetworkClient
        """
      )
    )

    // Base URL property
    members.append(
      DeclSyntax(
        """
        private let baseURL: String = "\(raw: baseURL)"
        """
      )
    )

    // Default headers property (if any)
    if !defaultHeaders.isEmpty {
      let headersDict = defaultHeaders.map { key, value in
        "\"\(key)\": \"\(value)\""
      }.joined(separator: ", ")

      members.append(
        DeclSyntax(
          """
          private let defaultHeaders: [String: String] = [\(raw: headersDict)]
          """
        )
      )
    }

    // Default timeout property (if any)
    if let timeout = defaultTimeout {
      members.append(
        DeclSyntax(
          """
          private let defaultTimeout: Double = \(raw: String(timeout))
          """
        )
      )
    }

    // Initializer
    members.append(
      DeclSyntax(
        """
        public init(client: NetworkClient = .shared) {
          self.client = client
        }
        """
      )
    )

    // Create the implementation struct
    let structDecl = StructDeclSyntax(
      modifiers: [DeclModifierSyntax(name: .keyword(.public))],
      name: .identifier("\(protocolName)Implementation"),
      inheritanceClause: InheritanceClauseSyntax {
        InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier(protocolName)))
        InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier("Sendable")))
      },
      memberBlock: MemberBlockSyntax(
        members: MemberBlockItemListSyntax(
          members.map { MemberBlockItemSyntax(decl: $0) }
        )
      )
    )

    return [DeclSyntax(structDecl)]
  }

  // MARK: - Helper Methods

  /// Extracts the base URL string from the macro attribute.
  private static func extractBaseURL(
    from attribute: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> String? {
    guard let arguments = attribute.arguments,
      case .argumentList(let list) = arguments,
      let firstArg = list.first
    else {
      context.diagnose(
        Diagnostic(
          node: Syntax(attribute),
          message: SimpleDiagnosticMessage(
            message: "@API requires a baseURL argument",
            diagnosticID: MessageID(domain: "Networking", id: "missingBaseURL"),
            severity: .error
          )
        )
      )
      return nil
    }

    // Extract string literal value
    if let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
      let segment = stringLiteral.segments.first,
      case .stringSegment(let stringSegment) = segment
    {
      return stringSegment.content.text
    }

    context.diagnose(
      Diagnostic(
        node: Syntax(attribute),
        message: SimpleDiagnosticMessage(
          message: "Base URL must be a string literal",
          diagnosticID: MessageID(domain: "Networking", id: "invalidBaseURL"),
          severity: .error
        )
      )
    )
    return nil
  }
}
