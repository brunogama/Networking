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

  static func invocationArgumentList(
    from signature: FunctionSignatureSyntax
  ) -> String {
    signature.parameterClause.parameters
      .map { parameter in
        let label = parameter.firstName.text
        let name = parameter.secondName?.text ?? label
        let prefix = label == "_" ? "" : "\(label): "
        let value = parameter.type.trimmedDescription.hasPrefix("inout ") ? "&\(name)" : name
        return "\(prefix)\(value)"
      }
      .joined(separator: ", ")
  }

  static func invocationPrefix(from signature: FunctionSignatureSyntax) -> String {
    [
      signature.effectSpecifiers?.throwsClause != nil ? "try" : nil,
      signature.effectSpecifiers?.asyncSpecifier != nil ? "await" : nil,
    ]
    .compactMap { $0 }
    .joined(separator: " ")
  }

}
