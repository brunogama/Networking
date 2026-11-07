import SwiftSyntax

enum FunctionSignatureAdapter {
  static func renderedSignature(
    for function: FunctionDeclSyntax,
    renamedTo name: String
  ) -> String {
    let modifiers = function.modifiers.trimmedDescription
    let genericParameters = function.genericParameterClause?.trimmedDescription ?? ""
    let parameterClause = function.signature.parameterClause.trimmedDescription
    let effectSpecifiers = function.signature.effectSpecifiers?.trimmedDescription
    let returnClause = function.signature.returnClause?.trimmedDescription
    let whereClause = function.genericWhereClause?.trimmedDescription

    return [
      modifiers.isEmpty ? nil : modifiers,
      "func \(name)\(genericParameters)\(parameterClause)",
      effectSpecifiers,
      returnClause,
      whereClause,
    ]
    .compactMap { $0 }
    .joined(separator: " ")
  }

}
