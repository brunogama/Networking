import SwiftSyntax

extension FunctionDeclSyntax {
  func detectBodyMacro() -> String? {
    for attribute in attributes {
      guard case .attribute(let attr) = attribute,
        let identType = attr.attributeName.as(IdentifierTypeSyntax.self),
        identType.name.text == "Body",
        case .argumentList(let arguments) = attr.arguments,
        let firstArg = arguments.first,
        let parameterName = BoundaryExpressionParser.string(from: firstArg.expression)
      else {
        continue
      }
      return parameterName
    }
    return nil
  }

  func detectHeadersMacro() -> [ParsedHeader] {
    var headers: [ParsedHeader] = []

    for attribute in attributes {
      guard case .attribute(let node) = attribute,
        node.attributeName.trimmedDescription == "Headers",
        let parsedHeaders = HeaderMacroParser.parseHeaders(from: node)
      else { continue }
      headers.append(contentsOf: parsedHeaders)
    }

    return headers
  }

}
