import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import Testing
@testable import NetworkingMacrosPlugin

func expandPeer(_ macro: any PeerMacro.Type, source: String) throws -> MacroTestExpansion {
  let input = try MacroTestInput(source)
  let context = BasicMacroExpansionContext()
  do {
    let declarations = try macro.expansion(
      of: input.attribute,
      providingPeersOf: input.declaration,
      in: context
    )
    return MacroTestExpansion(
      declarations: declarations,
      diagnostics: context.diagnostics,
      errors: []
    )
  } catch {
    return MacroTestExpansion(
      declarations: [],
      diagnostics: context.diagnostics,
      errors: [String(describing: error)]
    )
  }
}

func expandMember(_ macro: any MemberMacro.Type, source: String) throws -> MacroTestExpansion {
  let input = try MacroTestInput(source)
  let declaration = try #require(input.declaration.asProtocol(DeclGroupSyntax.self))
  let context = BasicMacroExpansionContext()
  let declarations = try macro.expansion(
    of: input.attribute,
    providingMembersOf: declaration,
    in: context
  )
  return MacroTestExpansion(
    declarations: declarations,
    diagnostics: context.diagnostics,
    errors: []
  )
}

var httpTestMacros: [String: any PeerMacro.Type] {
  [
    "GET": GETMacro.self,
    "POST": POSTMacro.self,
    "PUT": PUTMacro.self,
    "PATCH": PATCHMacro.self,
    "DELETE": DELETEMacro.self,
  ]
}
