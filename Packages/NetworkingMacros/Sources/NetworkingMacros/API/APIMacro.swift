import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation
import MacroTemplateKit

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

    // Extract interceptors from @Interceptors attribute
    let interceptorExprs = InterceptorsMacro.extractInterceptorExpressions(from: protocolDecl)
    let hasInterceptors = !interceptorExprs.isEmpty

    // Build member declarations using MacroTemplateKit
    var members: [Declaration<Void>] = []

    // NetworkClient property
    members.append(
      .property(
        PropertySignature(
          accessLevel: .private,
          name: "client",
          type: "NetworkClient",
          isStatic: false,
          isLet: true,
          initializer: nil
        )
      )
    )

    // Base URL property
    members.append(
      .property(
        PropertySignature(
          accessLevel: .private,
          name: "baseURL",
          type: "String",
          isStatic: false,
          isLet: true,
          initializer: .literal(.string(baseURL))
        )
      )
    )

    // Default headers property (if any)
    // Note: The actual initializer expression will be substituted after rendering
    // since dictionary literals require complex ExprSyntax handling
    if !defaultHeaders.isEmpty {
      members.append(
        .property(
          PropertySignature(
            accessLevel: .private,
            name: "defaultHeaders",
            type: "[String: String]",
            isStatic: false,
            isLet: true,
            initializer: nil  // Placeholder - replaced in replaceHeadersProperty
          )
        )
      )
    }

    // Default timeout property (if any)
    if let timeout = defaultTimeout {
      members.append(
        .property(
          PropertySignature(
            accessLevel: .private,
            name: "defaultTimeout",
            type: "Double",
            isStatic: false,
            isLet: true,
            initializer: .literal(.double(timeout))
          )
        )
      )
    }

    // Interceptor chain property (if any)
    if hasInterceptors {
      members.append(
        .property(
          PropertySignature(
            accessLevel: .private,
            name: "interceptors",
            type: "InterceptorChain",
            isStatic: false,
            isLet: true,
            initializer: nil
          )
        )
      )
    }

    // Initializer
    let initBody: [Statement<Void>] = buildInitializerBody(
      hasInterceptors: hasInterceptors,
      interceptorExprs: interceptorExprs
    )

    members.append(
      .initDecl(
        InitializerSignature(
          accessLevel: .public,
          parameters: [
            ParameterSignature(
              name: "client",
              type: "NetworkClient",
              defaultValue: ".shared"
            )
          ],
          canThrow: false,
          body: initBody
        )
      )
    )

    // Create the implementation struct using Declaration ADT
    let structDecl = Declaration<Void>.structDecl(
      StructSignature(
        accessLevel: .public,
        name: "\(protocolName)Implementation",
        conformances: [protocolName, "Sendable"],
        members: members
      )
    )

    // Render to DeclSyntax
    var resultDecl = Renderer.render(structDecl)

    // For defaultHeaders, we need to replace the placeholder property with the actual one
    // that has the complex initializer expression
    if !defaultHeaders.isEmpty {
      let headersExpr = DefaultHeadersMacro.generateHeadersExpression(from: defaultHeaders)
      resultDecl = replaceHeadersProperty(in: resultDecl, with: headersExpr)
    }

    return [resultDecl]
  }

  // MARK: - Helper Methods

  /// Builds the initializer body statements.
  private static func buildInitializerBody(
    hasInterceptors: Bool,
    interceptorExprs: [ExprSyntax]
  ) -> [Statement<Void>] {
    var body: [Statement<Void>] = []

    // self.client = client
    body.append(
      .expression(
        .binaryOperation(
          left: .propertyAccess(
            base: .variable("self", payload: ()),
            property: "client"
          ),
          operator: "=",
          right: .variable("client", payload: ())
        )
      )
    )

    if hasInterceptors {
      // Generate interceptor chain initialization
      // For complex expressions like InterceptorChain(...), we use a string-based approach
      // since the Template ADT doesn't support complex object construction directly
      let requestList = interceptorExprs.map { "\($0)" }.joined(separator: ", ")
      let responseList = interceptorExprs.map { "\($0)" }.joined(separator: ", ")

      // self.interceptors = InterceptorChain(requestInterceptors: [...], responseInterceptors: [...])
      body.append(
        .expression(
          .binaryOperation(
            left: .propertyAccess(
              base: .variable("self", payload: ()),
              property: "interceptors"
            ),
            operator: "=",
            right: .functionCall(
              function: "InterceptorChain",
              arguments: [
                (label: "requestInterceptors", value: .variable("[\(requestList)]", payload: ())),
                (label: "responseInterceptors", value: .variable("[\(responseList)]", payload: ())),
              ]
            )
          )
        )
      )
    }

    return body
  }

  /// Replaces the placeholder defaultHeaders property with one that has the actual initializer.
  private static func replaceHeadersProperty(
    in decl: DeclSyntax,
    with headersExpr: ExprSyntax
  ) -> DeclSyntax {
    guard let structDecl = decl.as(StructDeclSyntax.self) else {
      return decl
    }

    var newMembers: [MemberBlockItemSyntax] = []
    for member in structDecl.memberBlock.members {
      if let varDecl = member.decl.as(VariableDeclSyntax.self),
        let binding = varDecl.bindings.first,
        let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
        pattern.identifier.text == "defaultHeaders"
      {
        // Replace with the actual headers declaration
        let newDecl = VariableDeclSyntax(
          modifiers: [DeclModifierSyntax(name: .keyword(.private))],
          .let,
          name: PatternSyntax(IdentifierPatternSyntax(identifier: .identifier("defaultHeaders"))),
          type: TypeAnnotationSyntax(
            type: DictionaryTypeSyntax(
              key: IdentifierTypeSyntax(name: .identifier("String")),
              value: IdentifierTypeSyntax(name: .identifier("String"))
            )
          ),
          initializer: InitializerClauseSyntax(value: headersExpr)
        )
        newMembers.append(MemberBlockItemSyntax(decl: DeclSyntax(newDecl)))
      } else {
        newMembers.append(member)
      }
    }

    let newStruct = structDecl.with(
      \.memberBlock,
      MemberBlockSyntax(members: MemberBlockItemListSyntax(newMembers))
    )
    return DeclSyntax(newStruct)
  }

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
