import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

/// Generates GraphQL mutation request builder from function signature.
public struct MutationMacro: SwiftSyntaxMacros.BodyMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
    in context: some MacroExpansionContext
  ) throws -> [CodeBlockItemSyntax] {
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      let diagnostic = Diagnostic(
        node: Syntax(node),
        message: GraphQLMacroDiagnostic.mutationRequiresFunction
      )
      context.diagnose(diagnostic)
      return []
    }

    guard let queryString = QueryMacro.extractQueryString(from: node) else {
      let diagnostic = Diagnostic(
        node: Syntax(node),
        message: GraphQLMacroDiagnostic.mutationRequiresQueryString
      )
      context.diagnose(diagnostic)
      return []
    }

    let operationName = QueryMacro.extractOperationName(from: queryString) ?? "Mutation"
    let returnType = QueryMacro.extractReturnType(from: funcDecl)
    let variablesCode = QueryMacro.buildVariablesCode(from: funcDecl.signature.parameterClause.parameters)

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
}
