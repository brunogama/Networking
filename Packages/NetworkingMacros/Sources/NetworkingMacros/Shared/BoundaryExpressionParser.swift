import SwiftSyntax

enum BoundaryExpressionParser {
  static func string(from expression: some ExprSyntaxProtocol) -> String? {
    let expr = ExprSyntax(expression)

    if let stringLiteral = expr.as(StringLiteralExprSyntax.self),
      let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
    {
      return segment.content.text
    }

    if let functionCall = expr.as(FunctionCallExprSyntax.self),
      functionCall.arguments.count == 1,
      let argument = functionCall.arguments.first
    {
      return string(from: argument.expression)
    }

    return nil
  }

  static func integer(from expression: some ExprSyntaxProtocol) -> Int? {
    let expr = ExprSyntax(expression)

    if let intLiteral = expr.as(IntegerLiteralExprSyntax.self) {
      return Int(intLiteral.literal.text)
    }

    if let floatLiteral = expr.as(FloatLiteralExprSyntax.self),
      let value = Double(floatLiteral.literal.text),
      value.rounded() == value
    {
      return Int(value)
    }

    if let functionCall = expr.as(FunctionCallExprSyntax.self),
      functionCall.arguments.count == 1,
      let argument = functionCall.arguments.first
    {
      return integer(from: argument.expression)
    }

    return nil
  }

  static func double(from expression: some ExprSyntaxProtocol) -> Double? {
    let expr = ExprSyntax(expression)

    if let floatLiteral = expr.as(FloatLiteralExprSyntax.self) {
      return Double(floatLiteral.literal.text)
    }

    if let intLiteral = expr.as(IntegerLiteralExprSyntax.self) {
      return Double(intLiteral.literal.text)
    }

    if let functionCall = expr.as(FunctionCallExprSyntax.self),
      functionCall.arguments.count == 1,
      let argument = functionCall.arguments.first
    {
      return double(from: argument.expression)
    }

    return nil
  }

  static func dictionaryOfStrings(
    from expression: some ExprSyntaxProtocol
  ) -> [String: String]? {
    let expr = ExprSyntax(expression)

    if let array = expr.as(ArrayExprSyntax.self),
      array.elements.isEmpty
    {
      return [:]
    }

    guard let dictionary = expr.as(DictionaryExprSyntax.self),
      case .elements(let elements) = dictionary.content
    else {
      return nil
    }

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
