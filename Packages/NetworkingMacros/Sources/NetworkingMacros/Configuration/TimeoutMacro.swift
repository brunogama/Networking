import SwiftSyntax
import SwiftSyntaxMacros

/// Validates the default request timeout consumed by `@API`.
public struct TimeoutMacro: MemberMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard declaration.is(ProtocolDeclSyntax.self) else {
      MacroHelpers.emitError(
        "@Timeout can only be applied to protocols",
        id: .timeoutRequiresProtocol,
        node: node,
        context: context
      )
      return []
    }
    guard let timeout = seconds(from: node), timeout.isFinite, timeout > 0 else {
      MacroHelpers.emitError(
        "@Timeout requires a positive Duration literal in seconds, milliseconds, "
          + "microseconds, or nanoseconds",
        id: .invalidTimeout,
        node: node,
        context: context
      )
      return []
    }
    return []
  }

  static func extractDefaultTimeout(from declaration: some WithAttributesSyntax) -> Double? {
    for case .attribute(let attribute) in declaration.attributes
    where attribute.attributeName.trimmedDescription == "Timeout" {
      return seconds(from: attribute)
    }
    return nil
  }

  private static func seconds(from attribute: AttributeSyntax) -> Double? {
    guard case .argumentList(let arguments) = attribute.arguments,
      let expression = arguments.first?.expression,
      let call = expression.as(FunctionCallExprSyntax.self),
      let unit = call.calledExpression.as(MemberAccessExprSyntax.self),
      call.arguments.count == 1,
      let value = call.arguments.first?.expression,
      let magnitude = BoundaryExpressionParser.double(from: value),
      let multiplier = unitMultipliers[unit.declName.baseName.text]
    else { return nil }
    return magnitude * multiplier
  }

  private static let unitMultipliers: [String: Double] = [
    "seconds": 1,
    "milliseconds": 0.001,
    "microseconds": 0.000_001,
    "nanoseconds": 0.000_000_001,
  ]
}
