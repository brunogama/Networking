import SwiftSyntax

struct ParsedHeader: Equatable, Sendable {
  enum ValueSource: Equatable, Sendable {
    case literal(String)
    case parameter(String)

    var rawValue: String {
      switch self {
      case .literal(let value), .parameter(let value):
        value
      }
    }
  }

  let name: String
  let valueSource: ValueSource
}

enum HeaderMacroParser {
  static func closure(from node: AttributeSyntax) -> ClosureExprSyntax? {
    guard case .argumentList(let arguments) = node.arguments,
      let closureArgument = arguments.first
    else {
      return nil
    }

    return closureArgument.expression.as(ClosureExprSyntax.self)
  }

  static func closure(from attribute: AttributeListSyntax.Element) -> ClosureExprSyntax? {
    guard case .attribute(let attribute) = attribute,
      let identifierType = attribute.attributeName.as(IdentifierTypeSyntax.self),
      identifierType.name.text == "Headers"
    else {
      return nil
    }

    return closure(from: attribute)
  }

  static func parseHeaders(from closure: ClosureExprSyntax) -> [ParsedHeader] {
    closure.statements.compactMap(parseHeader(from:))
  }

  private static func parseHeader(from statement: CodeBlockItemSyntax) -> ParsedHeader? {
    guard
      let functionCall = statement.item.as(FunctionCallExprSyntax.self),
      let identifierExpression = functionCall.calledExpression.as(DeclReferenceExprSyntax.self),
      identifierExpression.baseName.text == "H"
    else {
      return nil
    }

    let arguments = Array(functionCall.arguments)
    guard arguments.count == 2,
      let name = BoundaryExpressionParser.string(from: arguments[0].expression),
      let valueSource = valueSource(from: arguments[1].expression)
    else {
      return nil
    }

    return ParsedHeader(name: name, valueSource: valueSource)
  }

  private static func valueSource(
    from expression: some ExprSyntaxProtocol
  ) -> ParsedHeader.ValueSource? {
    let expr = ExprSyntax(expression)

    if let functionCall = expr.as(FunctionCallExprSyntax.self),
      functionCall.arguments.count == 1,
      let argument = functionCall.arguments.first,
      let functionName = calledFunctionName(of: functionCall.calledExpression),
      let rawValue = BoundaryExpressionParser.string(from: argument.expression)
    {
      switch functionName {
      case "parameter":
        return .parameter(rawValue)
      case "literal":
        return .literal(rawValue)
      default:
        break
      }
    }

    return BoundaryExpressionParser.string(from: expr).map(ParsedHeader.ValueSource.literal)
  }

  private static func calledFunctionName(of expression: some ExprSyntaxProtocol) -> String? {
    let expr = ExprSyntax(expression)

    if let reference = expr.as(DeclReferenceExprSyntax.self) {
      return reference.baseName.text
    }

    if let memberAccess = expr.as(MemberAccessExprSyntax.self) {
      return memberAccess.declName.baseName.text
    }

    return nil
  }
}
