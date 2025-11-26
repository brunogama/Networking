import NetworkingMacros
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

/// Tests for @Body macro validation and behavior.
///
/// Note: @Body is a "marker macro" that generates no peer code (returns empty array).
/// It validates the body parameter exists and is used by HTTP method macros.
final class BodyMacroTests: XCTestCase {

  // MARK: - Success Cases

  func testBodyMacroBasicUsage() throws {
    // @Body should expand without errors when parameter exists
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Body("user")
      func createUser(user: User) async throws -> User
      """,
      expandedSource: """
        func createUser(user: User) async throws -> User
        """,
      macros: ["Body": BodyMacro.self]
    )
  }

  func testBodyMacroWithMultipleParameters() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Body("data")
      func sendData(id: String, data: RequestData, token: String) async throws -> Response
      """,
      expandedSource: """
        func sendData(id: String, data: RequestData, token: String) async throws -> Response
        """,
      macros: ["Body": BodyMacro.self]
    )
  }

  func testBodyMacroWithInternalParameterName() throws {
    // Test with external and internal parameter names
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Body("requestBody")
      func create(with requestBody: Data) async throws -> Response
      """,
      expandedSource: """
        func create(with requestBody: Data) async throws -> Response
        """,
      macros: ["Body": BodyMacro.self]
    )
  }

  // MARK: - Error Cases

  func testBodyMacroParameterNotFound() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Body("nonexistent")
      func createUser(user: User) async throws -> User
      """,
      expandedSource: """
        @Body("nonexistent")
        func createUser(user: User) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Body parameter 'nonexistent' not found in function signature. \
            Available: [user]
            """,
          line: 1,
          column: 1
        )
      ],
      macros: ["Body": BodyMacro.self]
    )
  }

  func testBodyMacroWithoutArgument() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Body
      func createUser(user: User) async throws -> User
      """,
      expandedSource: """
        @Body
        func createUser(user: User) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Body requires parameter name: @Body(\"parameterName\")",
          line: 1,
          column: 1
        )
      ],
      macros: ["Body": BodyMacro.self]
    )
  }

  func testBodyMacroOnNonFunction() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Body("value")
      struct MyStruct {}
      """,
      expandedSource: """
        @Body("value")
        struct MyStruct {}
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Body can only be applied to functions",
          line: 1,
          column: 1
        )
      ],
      macros: ["Body": BodyMacro.self]
    )
  }

  func testBodyMacroParameterNameMismatch() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Body("usr")
      func createUser(user: User) async throws -> User
      """,
      expandedSource: """
        @Body("usr")
        func createUser(user: User) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Body parameter 'usr' not found in function signature. \
            Available: [user]
            """,
          line: 1,
          column: 1
        )
      ],
      macros: ["Body": BodyMacro.self]
    )
  }

  func testMultipleBodyMacros() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Body("user")
      @Body("request")
      func create(user: User, request: Request) async throws -> Response
      """,
      expandedSource: """
        @Body("user")
        @Body("request")
        func create(user: User, request: Request) async throws -> Response
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Only one @Body macro allowed per function. Found 2.",
          line: 1,
          column: 1
        ),
        DiagnosticSpec(
          message: "Only one @Body macro allowed per function. Found 2.",
          line: 2,
          column: 1
        ),
      ],
      macros: ["Body": BodyMacro.self]
    )
  }

  // MARK: - Integration Scenarios

  func testBodyMacroWithPOST() throws {
    // Verify @Body works alongside @POST
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/users")
      @Body("user")
      func createUser(user: User) async throws -> User
      """,
      expandedSource: """
        @POST("/users")
        func createUser(user: User) async throws -> User
        """,
      macros: ["Body": BodyMacro.self]
    )
  }

  func testBodyMacroWithPUT() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PUT("/users/{id}")
      @Body("updates")
      func updateUser(id: String, updates: UserUpdates) async throws -> User
      """,
      expandedSource: """
        @PUT("/users/{id}")
        func updateUser(id: String, updates: UserUpdates) async throws -> User
        """,
      macros: ["Body": BodyMacro.self]
    )
  }

  func testBodyMacroWithPATCH() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH("/users/{id}")
      @Body("changes")
      func patchUser(id: String, changes: PartialUser) async throws -> User
      """,
      expandedSource: """
        @PATCH("/users/{id}")
        func patchUser(id: String, changes: PartialUser) async throws -> User
        """,
      macros: ["Body": BodyMacro.self]
    )
  }

  func testBodyMacroDoesNotGenerateCode() throws {
    // Verify that @Body generates no peer declarations (marker macro)
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Body("data")
      func send(data: Data) async throws -> Response
      """,
      expandedSource: """
        func send(data: Data) async throws -> Response
        """,
      macros: ["Body": BodyMacro.self]
    )
  }

  // MARK: - Edge Cases

  func testBodyMacroWithOptionalParameter() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Body("data")
      func send(data: Data?) async throws -> Response
      """,
      expandedSource: """
        func send(data: Data?) async throws -> Response
        """,
      macros: ["Body": BodyMacro.self]
    )
  }

  func testBodyMacroWithGenericParameter() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Body("items")
      func sendItems<T: Encodable>(items: [T]) async throws -> Response
      """,
      expandedSource: """
        func sendItems<T: Encodable>(items: [T]) async throws -> Response
        """,
      macros: ["Body": BodyMacro.self]
    )
  }
}
