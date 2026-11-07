import SwiftSyntax
import SwiftSyntaxBuilder

extension APIMacro {
  static func makeImplementation(
    for protocolDeclaration: ProtocolDeclSyntax,
    baseURL: String,
    accessLevel: APIAccessLevel?,
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
    let modifiers = DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.private))])

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


  static func makeFactory(
    for protocolDeclaration: ProtocolDeclSyntax,
    accessLevel: APIAccessLevel?
  ) -> DeclSyntax {
    let protocolName = protocolDeclaration.name.text
    let factoryAccess = accessLevel?.sourcePrefix ?? ""
    let methodAccess = accessLevel.map { $0.peerAccessLevel.sourcePrefix } ?? ""
    return DeclSyntax(
      stringLiteral: """
        \(factoryAccess)enum \(protocolName)Factory {
          \(methodAccess)static func make(
            client: any HTTPClient = NetworkClient(),
            codec: JSONCodec = JSONCodec()
          ) -> any \(protocolName) {
            \(protocolName)Implementation(client: client, codec: codec)
          }
        }
        """
    )
  }
  private static func implementationMembers(
    for protocolDeclaration: ProtocolDeclSyntax,
    baseURL: String,
    accessLevel: APIAccessLevel?,
    methods: [DeclSyntax]
  ) -> [DeclSyntax] {
    let defaultHeaders = DefaultHeadersMacro.extractDefaultHeaders(from: protocolDeclaration)
    let timeout = TimeoutMacro.extractDefaultTimeout(from: protocolDeclaration) ?? 30
    var members: [DeclSyntax] = [
      "private let client: any HTTPClient",
      "private let codec: JSONCodec",
      "private let baseURL: BaseURLText = BaseURLText(rawValue: \(raw: swiftLiteral(baseURL)))",
      "private let defaultHeaders: HTTPHeaders = \(raw: headersLiteral(defaultHeaders))",
      "private let defaultTimeout = NetworkingCore.RequestTimeout(rawValue: \(raw: String(timeout)))",
    ]
    members.append(
      initializer(accessLevel: accessLevel)
    )
    members.append(contentsOf: methods)
    return members
  }

  private static func initializer(accessLevel: APIAccessLevel?) -> DeclSyntax {
    let accessPrefix = accessLevel?.sourcePrefix ?? ""
    return DeclSyntax(
      stringLiteral: """
        \(accessPrefix)init(client: any HTTPClient, codec: JSONCodec) {
          self.client = client
          self.codec = codec
        }
        """
    )
  }

  static func declaredAccessLevel(
    of protocolDeclaration: ProtocolDeclSyntax
  ) -> APIAccessLevel? {
    APIAccessLevel(modifiers: protocolDeclaration.modifiers)
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
