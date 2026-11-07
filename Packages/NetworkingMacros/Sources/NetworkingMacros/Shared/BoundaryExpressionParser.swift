import Foundation
import SwiftParser
import SwiftSyntax

enum BoundaryExpressionParser {
  static func string(from expression: some ExprSyntaxProtocol) -> String? {
    let expr = ExprSyntax(expression)

    if let stringLiteral = expr.as(StringLiteralExprSyntax.self),
      let value = stringLiteral.representedLiteralValue
    {
      return value
    }

    if let functionCall = expr.as(FunctionCallExprSyntax.self),
      functionCall.arguments.count == 1,
      let argument = functionCall.arguments.first
    {
      return string(from: argument.expression)
    }

    return nil
  }

  static func double(from expression: some ExprSyntaxProtocol) -> Double? {
    let expr = ExprSyntax(expression)

    if let floatLiteral = expr.as(FloatLiteralExprSyntax.self) {
      return Double(floatLiteral.literal.text.replacingOccurrences(of: "_", with: ""))
    }

    if let intLiteral = expr.as(IntegerLiteralExprSyntax.self) {
      return Double(intLiteral.literal.text.replacingOccurrences(of: "_", with: ""))
    }

    return nil
  }

  static func dictionaryOfStrings(
    from expression: some ExprSyntaxProtocol
  ) -> [String: String]? {
    let expr = ExprSyntax(expression)

    guard let dictionary = expr.as(DictionaryExprSyntax.self) else { return nil }
    guard case .elements(let elements) = dictionary.content else { return [:] }

    var result: [String: String] = [:]

    for element in elements {
      guard let key = string(from: element.key),
        let value = string(from: element.value)
      else {
        return nil
      }

      result[key] = value
    }

    return result
  }

  static func arrayOfStrings(from expression: some ExprSyntaxProtocol) -> [String]? {
    let expr = ExprSyntax(expression)

    guard let array = expr.as(ArrayExprSyntax.self) else {
      return nil
    }

    var result: [String] = []

    for element in array.elements {
      guard let value = string(from: element.expression) else {
        return nil
      }

      result.append(value)
    }

    return result
  }
}
