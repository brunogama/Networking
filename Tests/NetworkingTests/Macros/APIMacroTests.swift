#if MACRO_TESTS_ENABLED
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import NetworkingMacros

/// Tests for @API macro expansion.
final class APIMacroTests: XCTestCase {
  // MARK: - Success Cases

  func testAPIBasicExpansion() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
      }
      """,
      expandedSource: """
        protocol UserAPI {

            public struct UserAPIImplementation: UserAPI, Sendable {
                private let client: NetworkClient
                private let baseURL: String = "https://api.example.com"
                public init(client: NetworkClient = .shared) {
                  self.client = client
                }
            }
        }
        """,
      macros: ["API": APIMacro.self]
    )
  }

  func testAPIWithComplexProtocolName() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.example.com/v2")
      protocol MyComplexAPIServiceProtocol {
      }
      """,
      expandedSource: """
        protocol MyComplexAPIServiceProtocol {

            public struct MyComplexAPIServiceProtocolImplementation: MyComplexAPIServiceProtocol, Sendable {
                private let client: NetworkClient
                private let baseURL: String = "https://api.example.com/v2"
                public init(client: NetworkClient = .shared) {
                  self.client = client
                }
            }
        }
        """,
      macros: ["API": APIMacro.self]
    )
  }

  // MARK: - Error Cases

  func testAPIRequiresProtocol() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.example.com")
      struct UserAPI {
      }
      """,
      expandedSource: """
        struct UserAPI {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@API can only be applied to protocols",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["API": APIMacro.self]
    )
  }

  func testAPIRequiresBaseURL() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API
      protocol UserAPI {
      }
      """,
      expandedSource: """
        protocol UserAPI {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@API requires a baseURL argument",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["API": APIMacro.self]
    )
  }

  func testAPIRequiresStringLiteral() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: someVariable)
      protocol UserAPI {
      }
      """,
      expandedSource: """
        protocol UserAPI {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Base URL must be a string literal",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["API": APIMacro.self]
    )
  }

  func testAPIRejectsEmptyBaseURL() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "")
      protocol UserAPI {
      }
      """,
      expandedSource: """
        protocol UserAPI {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Base URL cannot be empty",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["API": APIMacro.self]
    )
  }
}
#endif
