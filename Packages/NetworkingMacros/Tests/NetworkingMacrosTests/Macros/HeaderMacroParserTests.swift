import SwiftParser
import SwiftSyntax
import XCTest
@testable import NetworkingMacrosPlugin

final class HeaderMacroParserTests: XCTestCase {
  func testParseHeadersKeepsLiteralValuesLiteral() throws {
    let closure = try parsedClosure(
      from:
        """
        let headers = {
          H(.named("Authorization"), .literal("token"))
        }
        """
    )

    XCTAssertEqual(
      HeaderMacroParser.parseHeaders(from: closure),
      [ParsedHeader(name: "Authorization", valueSource: .literal("token"))]
    )
  }

  func testParseHeadersKeepsParameterReferencesExplicit() throws {
    let closure = try parsedClosure(
      from:
        """
        let headers = {
          H(.named("Authorization"), .parameter("token"))
        }
        """
    )

    XCTAssertEqual(
      HeaderMacroParser.parseHeaders(from: closure),
      [ParsedHeader(name: "Authorization", valueSource: .parameter("token"))]
    )
  }

  private func parsedClosure(from source: String) throws -> ClosureExprSyntax {
    let file = Parser.parse(source: source)

    guard
      let variable = file.statements.compactMap({ $0.item.as(VariableDeclSyntax.self) }).first,
      let binding = variable.bindings.first,
      let initializer = binding.initializer,
      let closure = initializer.value.as(ClosureExprSyntax.self)
    else {
      throw TestFailure("Expected a closure initializer")
    }

    return closure
  }
}

private struct TestFailure: Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}
