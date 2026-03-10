import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

internal struct SimpleDiagnosticMessage: DiagnosticMessage {
  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity
}

enum ConfigurationMacroDiagnostic: String, DiagnosticMessage {
  case cacheableRequiresProtocol
  case measuredRequiresFunction

  var message: String {
    switch self {
    case .cacheableRequiresProtocol:
      return "@Cacheable can only be applied to protocols"
    case .measuredRequiresFunction:
      return "@Measured can only be applied to functions"
    }
  }

  var diagnosticID: MessageID {
    MessageID(domain: "NetworkingMacros.Configuration", id: rawValue)
  }

  var severity: DiagnosticSeverity { .error }
}

extension MacroHelpers {
  static func emitError(
    _ message: String,
    node: some SyntaxProtocol,
    context: some MacroExpansionContext
  ) {
    context.diagnose(
      Diagnostic(
        node: Syntax(node),
        message: SimpleDiagnosticMessage(
          message: message,
          diagnosticID: MessageID(domain: "Networking", id: "error"),
          severity: .error
        )
      )
    )
  }

  static func emitWarning(
    _ message: String,
    node: some SyntaxProtocol,
    context: some MacroExpansionContext
  ) {
    context.diagnose(
      Diagnostic(
        node: Syntax(node),
        message: SimpleDiagnosticMessage(
          message: message,
          diagnosticID: MessageID(domain: "Networking", id: "warning"),
          severity: .warning
        )
      )
    )
  }
}
