import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct NetworkingGraphQLMacrosPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    QueryMacro.self,
    MutationMacro.self,
  ]
}
