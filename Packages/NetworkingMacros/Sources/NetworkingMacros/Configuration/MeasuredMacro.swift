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
        message: ConfigurationMacroDiagnostic.measuredRequiresFunction
      )
      context.diagnose(diagnostic)
      return []
    }

    let funcName = funcDecl.name.text
    let metricName =
      MacroHelpers.extractStringValue(labeled: "name", from: node) ?? funcName
    let signature = funcDecl.signature

    let wrapperSignature = FunctionSignatureAdapter.renderedSignature(
      for: funcDecl,
      renamedTo: "\(funcName)_measured"
    )
    let callPrefix = FunctionSignatureAdapter.invocationPrefix(from: signature)
    let invocationArguments = FunctionSignatureAdapter.invocationArgumentList(from: signature)
    let metricNameLiteral = metricName.debugDescription

    return [
      DeclSyntax(
        """
        \(raw: wrapperSignature) {
          let startTime = Date()
          defer {
            let duration = Duration.seconds(Date().timeIntervalSince(startTime))
            Metrics.shared.record(duration: duration, operation: \(raw: metricNameLiteral))
          }
          return \(raw: callPrefix.isEmpty ? "" : "\(callPrefix) ")\(raw: funcName)(\(raw: invocationArguments))
        }
        """
      )
    ]
  }
}
