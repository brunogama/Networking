import SwiftSyntax

extension HTTPMethodImplementationBuilder {
  struct Input {
    let function: FunctionDeclSyntax
    let returnType: String
    let pathCode: String
    let method: String
    let bodyParameter: String?
    let queryParameters: [String]
    let headers: [ParsedHeader]
    let accessLevel: APIAccessLevel?
  }
}
