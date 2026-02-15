import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

/// Generates GraphQL query request builder from function signature.
public struct QueryMacro: SwiftSyntaxMacros.BodyMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
    in context: some MacroExpansionContext
  ) throws -> [CodeBlockItemSyntax] {
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      let diagnostic = Diagnostic(
        node: Syntax(node),
        message: GraphQLMacroDiagnostic.queryRequiresFunction
      )
      context.diagnose(diagnostic)
      return []
    }

    guard let queryString = extractQueryString(from: node) else {
      let diagnostic = Diagnostic(
        node: Syntax(node),
        message: GraphQLMacroDiagnostic.queryRequiresQueryString
      )
      context.diagnose(diagnostic)
      return []
    }

    let operationName = extractOperationName(from: queryString) ?? "Query"
    let returnType = extractReturnType(from: funcDecl)
    let variablesCode = buildVariablesCode(from: funcDecl.signature.parameterClause.parameters)

    return [
      """
      let request = GraphQLRequest(
        query: \"\"\"\n\(raw: queryString)\n\"\"\",
        variables: \(raw: variablesCode),
        operationName: "\(raw: operationName)"
      )
      return try await graphQL.execute(request, as: \(raw: returnType).self)
      """
    ]
  }

  static func extractQueryString(from node: AttributeSyntax) -> String? {
    guard let arguments = node.arguments else { return nil }
    if case let .argumentList(list) = arguments,
      let firstArg = list.first,
      let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self)
    {
      return extractStringContent(from: stringLiteral)
    }
    return nil
  }

  static func extractStringContent(from literal: StringLiteralExprSyntax) -> String? {
    literal.segments.compactMap { segment -> String? in
      if let textSegment = segment.as(StringSegmentSyntax.self) {
        return textSegment.content.text
      }
      return nil
    }.joined()
  }

  static func extractOperationName(from query: String) -> String? {
    let pattern = #"(query|mutation)\s+(\w+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
      let nameRange = Range(match.range(at: 2), in: query)
    else {
      return nil
    }
    return String(query[nameRange])
  }

  static func extractReturnType(from funcDecl: FunctionDeclSyntax) -> String {
    guard let returnClause = funcDecl.signature.returnClause else {
      return "Void"
    }
    return returnClause.type.description.trimmingCharacters(in: .whitespaces)
  }

  static func buildVariablesCode(from parameters: FunctionParameterListSyntax) -> String {
    let entries = parameters.compactMap { param -> String? in
      let paramName = (param.secondName ?? param.firstName).text
      let typeName = param.type.description.trimmingCharacters(in: .whitespaces)
      let graphQLValue = mapTypeToGraphQLValue(typeName: typeName, paramName: paramName)
      return "\"\(paramName)\": \(graphQLValue)"
    }
    return "[\(entries.joined(separator: ", "))]"
  }

  private static func mapTypeToGraphQLValue(typeName: String, paramName: String) -> String {
    switch typeName {
    case "String":
      return ".string(\(paramName))"
    case "Int":
      return ".int(\(paramName))"
    case "Double":
      return ".double(\(paramName))"
    case "Bool":
      return ".bool(\(paramName))"
    default:
      return ".string(String(describing: \(paramName)))"
    }
  }
}

enum GraphQLMacroDiagnostic: String, DiagnosticMessage {
  case queryRequiresFunction
  case queryRequiresQueryString
  case mutationRequiresFunction
  case mutationRequiresQueryString

  var message: String {
    switch self {
    case .queryRequiresFunction:
      return "@Query can only be applied to functions"
    case .queryRequiresQueryString:
      return "@Query requires a query string argument"
    case .mutationRequiresFunction:
      return "@Mutation can only be applied to functions"
    case .mutationRequiresQueryString:
      return "@Mutation requires a mutation string argument"
    }
  }

  var diagnosticID: MessageID {
    MessageID(domain: "NetworkingMacros", id: rawValue)
  }

  var severity: DiagnosticSeverity { .error }
}
