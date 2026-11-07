import SwiftSyntax

struct HTTPMacroEndpointInput {
  let function: FunctionDeclSyntax
  let node: AttributeSyntax
  let path: String
  let bodyParameter: String?
  let headers: [ParsedHeader]
  let accessLevel: APIAccessLevel?
}
