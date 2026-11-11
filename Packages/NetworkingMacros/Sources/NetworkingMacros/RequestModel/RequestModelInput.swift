import SwiftSyntax
import SwiftSyntaxMacros

struct RequestModelInput {
  let method: ExprSyntax
  let path: String

  static func parse(
    from node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> Self? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
      let method = arguments.first(where: { $0.label?.text == "method" })?.expression,
      let pathExpression = arguments.first(where: { $0.label?.text == "path" })?.expression,
      let path = BoundaryExpressionParser.string(from: pathExpression)
    else {
      MacroHelpers.emitError(
        "@RequestModel requires method: and path: arguments",
        id: .requestModelRequiresRoute,
        node: node,
        context: context
      )
      return nil
    }

    return Self(method: method, path: path)
  }
}
