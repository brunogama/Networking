import SwiftSyntax

struct APIExpansionInput {
  let protocolDeclaration: ProtocolDeclSyntax
  let baseURL: String
  let accessLevel: APIAccessLevel?
}
