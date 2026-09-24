import SwiftSyntax
import SwiftSyntaxBuilder

extension APIMacro {
  static func makeImplementation(
    for protocolDeclaration: ProtocolDeclSyntax,
    baseURL: String,
    accessLevel: String?,
    methods: [DeclSyntax]
  ) -> DeclSyntax {
    let protocolName = protocolDeclaration.name.text
    let implementationName = "\(protocolName)Implementation"
    let members = implementationMembers(
      for: protocolDeclaration,
      baseURL: baseURL,
      accessLevel: accessLevel,
      methods: methods
    )
    let modifiers =
      accessLevel.map {
        DeclModifierListSyntax([DeclModifierSyntax(name: .identifier($0))])
      } ?? []

    return DeclSyntax(
      StructDeclSyntax(
        modifiers: modifiers,
        name: .identifier(implementationName),
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
    )
  }

  private static func implementationMembers(
    for protocolDeclaration: ProtocolDeclSyntax,
    baseURL: String,
    accessLevel: String?,
    methods: [DeclSyntax]
  ) -> [DeclSyntax] {
    let defaultHeaders = DefaultHeadersMacro.extractDefaultHeaders(from: protocolDeclaration)
    let timeout = TimeoutMacro.extractDefaultTimeout(from: protocolDeclaration) ?? 30
    let interceptors = InterceptorsMacro.extractInterceptorExpressions(from: protocolDeclaration)
    var members: [DeclSyntax] = [
      "private let client: any HTTPClient",
      "private let baseURL: BaseURLText = BaseURLText(rawValue: \(raw: swiftLiteral(baseURL)))",
      "private let defaultHeaders: HTTPHeaders = \(raw: headersLiteral(defaultHeaders))",
      "private let defaultTimeout = NetworkingCore.RequestTimeout(rawValue: \(raw: String(timeout)))",
    ]
    if !interceptors.isEmpty {
      members.append("private let interceptors: InterceptorChain")
    }
    members.append(initializer(accessLevel: accessLevel, interceptorExpressions: interceptors))
    members.append(contentsOf: methods)
    return members
  }

  private static func initializer(
    accessLevel: String?,
    interceptorExpressions: [ExprSyntax]
  ) -> DeclSyntax {
    let accessPrefix = accessLevel.map { "\($0) " } ?? ""
    var assignments = ["self.client = client"]
    if !interceptorExpressions.isEmpty {
      let expressions = interceptorExpressions.map(\.trimmedDescription).joined(separator: ", ")
      assignments.append(
        "let configuredInterceptors: [any Sendable] = [\(expressions)]"
      )
      assignments.append(
        "self.interceptors = InterceptorChain("
          + "requestInterceptors: configuredInterceptors.compactMap { "
          + "$0 as? any RequestInterceptor }, "
          + "responseInterceptors: configuredInterceptors.compactMap { "
          + "$0 as? any ResponseInterceptor })"
      )
    }

    let body = assignments.map { "  \($0)" }.joined(separator: "\n")
    return DeclSyntax(
      stringLiteral: """
        \(accessPrefix)init(client: any HTTPClient = NetworkClient()) {
        \(body)
        }
        """
    )
  }

  static func declaredAccessLevel(
    of protocolDeclaration: ProtocolDeclSyntax
  ) -> String? {
    let supported = Set(["public", "package", "fileprivate", "private"])
    return protocolDeclaration.modifiers
      .map(\.name.text)
      .first(where: supported.contains)
  }

  private static func headersLiteral(_ headers: [String: String]) -> String {
    guard !headers.isEmpty else { return "[:]" }
    let entries = headers.sorted { $0.key < $1.key }.map { key, value in
      "\(swiftLiteral(key)): \(swiftLiteral(value))"
    }
    return "[\(entries.joined(separator: ", "))]"
  }

  private static func swiftLiteral(_ value: String) -> String {
    String(reflecting: value)
  }
}
