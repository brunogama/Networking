import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import Testing
@testable import NetworkingMacrosPlugin

struct MacroTestInput {
  let declaration: DeclSyntax
  let attribute: AttributeSyntax

  init(_ source: String) throws {
    let file = Parser.parse(source: source)
    declaration = try #require(file.statements.first?.item.as(DeclSyntax.self))
    let attributed = try #require(declaration.asProtocol(WithAttributesSyntax.self))
    let firstAttribute = try #require(attributed.attributes.first)
    attribute = try #require(firstAttribute.as(AttributeSyntax.self))
  }
}
