import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import Testing
@testable import NetworkingMacrosPlugin

struct MacroTestExpansion {
  let declarations: [DeclSyntax]
  let diagnostics: [Diagnostic]
  let errors: [String]

  var source: String { declarations.map(\.description).joined(separator: "\n") }
  var messages: [String] { diagnostics.map(\.message) + errors }
  var diagnosticIDs: [String] {
    diagnostics.compactMap { ($0.diagMessage as? SimpleDiagnosticMessage)?.identifier.rawValue }
  }
}
