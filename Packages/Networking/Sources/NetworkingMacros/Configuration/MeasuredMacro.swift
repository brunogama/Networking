import SwiftDiagnostics
import SwiftSyntax
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
        message: ConfigurationMacroDiagnostic.measuredRequiresFunction
      )
      context.diagnose(diagnostic)
      return []
    }

    let funcName = funcDecl.name.text
    let metricName =
      MacroHelpers.extractStringValue(labeled: "name", from: node) ?? funcName
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

  /// Builds parameter pass-through for the wrapper function call
  /// - Parameter signature: Function signature to extract parameters from
  /// - Returns: Comma-separated parameter list for function call
  private static func buildParameterPassthrough(from signature: FunctionSignatureSyntax) -> String {
    signature.parameterClause.parameters.map { param in
      let label = param.firstName.text
      let name = param.secondName?.text ?? label
      return label == "_" ? name : "\(label): \(name)"
    }.joined(separator: ", ")
  }
}
