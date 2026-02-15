import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Generates a timing wrapper function for performance measurement.
///
/// Example:
/// ```swift
/// @Measured
/// func fetchUsers() async throws -> [User] {
///   return try await api.getUsers()
/// }
/// ```
///
/// Expands to:
/// ```swift
/// func fetchUsers_measured() async throws -> [User] {
///   let startTime = Date()
///   defer {
///     let duration = Date().timeIntervalSince(startTime)
///     Metrics.shared.record(duration: duration, operation: "fetchUsers")
///   }
///   return try await fetchUsers()
/// }
/// ```
public struct MeasuredMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Verify applied to function
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      let diagnostic = Diagnostic(
        node: Syntax(node),
        message: MacroDiagnostic.measuredRequiresFunction
      )
      context.diagnose(diagnostic)
      return []
    }

    let funcName = funcDecl.name.text
    let metricName = extractMetricName(from: node) ?? funcName
    let signature = funcDecl.signature
    let parameterList = buildParameterPassthrough(from: signature)

    // Generate wrapper function
    let wrapperCode: DeclSyntax = """
      func \(raw: funcName)_measured\(raw: signature.description) {
        let startTime = Date()
        defer {
          let duration = Date().timeIntervalSince(startTime)
          Metrics.shared.record(duration: duration, operation: "\(raw: metricName)")
        }
        return try await \(raw: funcName)(\(raw: parameterList))
      }
      """

    return [wrapperCode]
  }

  private static func extractMetricName(from node: AttributeSyntax) -> String? {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      return nil
    }

    for argument in arguments {
      if argument.label?.text == "name",
        let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
        let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
      {
        return segment.content.text
      }
    }
    return nil
  }

  private static func buildParameterPassthrough(from signature: FunctionSignatureSyntax) -> String {
    signature.parameterClause.parameters.map { param in
      let label = param.firstName.text
      return label == "_" ? param.secondName?.text ?? "" : "\(label): \(param.secondName?.text ?? label)"
    }.joined(separator: ", ")
  }
}
