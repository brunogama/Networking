import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

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
      guard let closure = HeaderMacroParser.closure(from: attribute) else {
        continue
      }

      headers.append(contentsOf: HeaderMacroParser.parseHeaders(from: closure))
    }

    return headers
  }

  func usesOldMacroSyntax() -> Bool {
    for attribute in attributes {
      guard case .attribute(let attr) = attribute,
        case .argumentList(let arguments) = attr.arguments
      else {
        continue
      }

      for argument in arguments {
        if let label = argument.label?.text,
          label == "body" || label == "headers"
        {
          return true
        }
      }
    }
    return false
  }
}
