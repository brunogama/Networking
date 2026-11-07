import SwiftCompilerPlugin
import SwiftSyntaxMacros

// Main plugin for all networking macros.
@main
struct NetworkingPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    APIMacro.self,
    GETMacro.self,
    POSTMacro.self,
    PUTMacro.self,
    PATCHMacro.self,
    DELETEMacro.self,
    DefaultHeadersMacro.self,
    TimeoutMacro.self,
    BodyMacro.self,
    HeaderMacro.self,
    HeadersMacro.self,
    RequestModelMacro.self,
  ]
}
