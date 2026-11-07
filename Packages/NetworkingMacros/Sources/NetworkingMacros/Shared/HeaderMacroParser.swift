import SwiftSyntax

enum HeaderMacroParser {
  static func parseHeaders(from node: AttributeSyntax) -> [ParsedHeader]? {
    guard case .argumentList(let arguments) = node.arguments,
      let expression = arguments.first?.expression,
      let dictionary = expression.as(DictionaryExprSyntax.self)
    else { return nil }
    guard case .elements(let elements) = dictionary.content else { return [] }

    var headers: [ParsedHeader] = []
    for element in elements {
      guard let name = BoundaryExpressionParser.string(from: element.key),
        let source = valueSource(from: element.value)
      else { return nil }
      headers.append(ParsedHeader(name: name, valueSource: source))
    }
    return headers
  }

  private static func valueSource(from expression: ExprSyntax) -> ParsedHeader.ValueSource? {
    guard let call = expression.as(FunctionCallExprSyntax.self),
      let member = call.calledExpression.as(MemberAccessExprSyntax.self),
      call.arguments.count == 1,
      let argument = call.arguments.first,
      let value = BoundaryExpressionParser.string(from: argument.expression)
    else { return nil }

    switch member.declName.baseName.text {
    case "parameter": return .parameter(value)
    case "literal": return .literal(value)
    default: return nil
    }
  }
}
