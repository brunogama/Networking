import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

internal struct SimpleDiagnosticMessage: DiagnosticMessage {
  let message: String
  let identifier: MacroDiagnosticID
  let severity: DiagnosticSeverity

  var diagnosticID: MessageID {
    MessageID(domain: "Networking", id: identifier.rawValue)
  }
}

extension MacroHelpers {
  static func emitError(
    _ message: String,
    id: MacroDiagnosticID,
    node: some SyntaxProtocol,
    context: some MacroExpansionContext
  ) {
    context.diagnose(
      Diagnostic(
        node: Syntax(node),
        message: SimpleDiagnosticMessage(
          message: message,
          identifier: id,
          severity: .error
        )
      )
    )
  }

}
