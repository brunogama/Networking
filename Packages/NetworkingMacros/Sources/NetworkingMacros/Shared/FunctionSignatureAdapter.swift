import MacroTemplateKit
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
    parameterSignatures(from: signature)
      .map(invocationArgument(for:))
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

  static func parameterSignatures(
    from signature: FunctionSignatureSyntax
  ) -> [ParameterSignature] {
    signature.parameterClause.parameters.map { parameter in
      let typeDescription = parameter.type.trimmedDescription
      let isInout = typeDescription.hasPrefix("inout ")
      let normalizedType =
        isInout ? String(typeDescription.dropFirst("inout ".count)) : typeDescription

      return ParameterSignature(
        label: parameter.firstName.text == "_" ? "_" : parameter.firstName.text,
        name: parameter.secondName?.text ?? parameter.firstName.text,
        type: normalizedType,
        isInout: isInout,
        defaultValue: parameter.defaultValue?.value.trimmedDescription
      )
    }
  }

  private static func invocationArgument(for parameter: ParameterSignature) -> String {
    let label = parameter.label == "_" ? nil : parameter.label
    let argumentLabel = label.map { "\($0): " } ?? ""
    let value = parameter.isInout ? "&\(parameter.name)" : parameter.name
    return "\(argumentLabel)\(value)"
  }
}
