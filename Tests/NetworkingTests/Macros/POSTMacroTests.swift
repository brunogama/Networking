import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import NetworkingMacros

/// Tests for @POST macro expansion.
final class POSTMacroTests: XCTestCase {
  // MARK: - Success Cases

  func testPOSTBasicExpansion() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/users", body: "user")
      func createUser(user: User) async throws -> User
      """,
      expandedSource: """
        func createUser(user: User) async throws -> User

        func createUser(user: User) async throws -> User {
          let path = "/users"
          var request = HTTPRequest(method: .POST, path: path)
          request.setBody(try JSONEncoder().encode(user))
          request.addHeader(name: "Content-Type", value: "application/json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      macros: ["POST": POSTMacro.self]
    )
  }

  func testPOSTWithPathParameters() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/teams/{teamId}/users", body: "user")
      func addUserToTeam(teamId: String, user: User) async throws -> User
      """,
      expandedSource: """
        func addUserToTeam(teamId: String, user: User) async throws -> User

        func addUserToTeam(teamId: String, user: User) async throws -> User {
          let path = "/teams/\\(teamId)/users"
          var request = HTTPRequest(method: .POST, path: path)
          request.setBody(try JSONEncoder().encode(user))
          request.addHeader(name: "Content-Type", value: "application/json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      macros: ["POST": POSTMacro.self]
    )
  }

  func testPOSTWithQueryParameters() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/users", body: "user", queryParameters: ["notify"])
      func createUser(user: User, notify: Bool) async throws -> User
      """,
      expandedSource: """
        func createUser(user: User, notify: Bool) async throws -> User

        func createUser(user: User, notify: Bool) async throws -> User {
          let path = "/users"
          var request = HTTPRequest(method: .POST, path: path)
          request.setBody(try JSONEncoder().encode(user))
          request.addHeader(name: "Content-Type", value: "application/json")
          request.addQueryParameter(name: "notify", value: \\(notify))
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      macros: ["POST": POSTMacro.self]
    )
  }

  func testPOSTWithCustomHeaders() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/users", body: "user", headers: ["X-API-Version": "v2"])
      func createUser(user: User) async throws -> User
      """,
      expandedSource: """
        func createUser(user: User) async throws -> User

        func createUser(user: User) async throws -> User {
          let path = "/users"
          var request = HTTPRequest(method: .POST, path: path)
          request.setBody(try JSONEncoder().encode(user))
          request.addHeader(name: "Content-Type", value: "application/json")
          request.addHeader(name: "X-API-Version", value: "v2")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      macros: ["POST": POSTMacro.self]
    )
  }

  func testPOSTWithPathQueryAndHeaders() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/teams/{teamId}/users", body: "user", queryParameters: ["notify"], headers: ["X-Request-ID": "123"])
      func addUser(teamId: String, user: User, notify: Bool) async throws -> User
      """,
      expandedSource: """
        func addUser(teamId: String, user: User, notify: Bool) async throws -> User

        func addUser(teamId: String, user: User, notify: Bool) async throws -> User {
          let path = "/teams/\\(teamId)/users"
          var request = HTTPRequest(method: .POST, path: path)
          request.setBody(try JSONEncoder().encode(user))
          request.addHeader(name: "Content-Type", value: "application/json")
          request.addHeader(name: "X-Request-ID", value: "123")
          request.addQueryParameter(name: "notify", value: \\(notify))
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      macros: ["POST": POSTMacro.self]
    )
  }

  // MARK: - Error Cases

  func testPOSTRequiresAsyncThrows() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/users", body: "user")
      func createUser(user: User) -> User
      """,
      expandedSource: """
        func createUser(user: User) -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Function 'createUser' must be marked 'async'",
          line: 1,
          column: 1
        )
      ],
      macros: ["POST": POSTMacro.self]
    )
  }

  func testPOSTRequiresPath() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST
      func createUser(user: User) async throws -> User
      """,
      expandedSource: """
        func createUser(user: User) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@POST requires a path argument",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["POST": POSTMacro.self]
    )
  }

  func testPOSTRequiresBodyParameter() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/users")
      func createUser(user: User) async throws -> User
      """,
      expandedSource: """
        func createUser(user: User) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@POST requires a 'body' argument",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["POST": POSTMacro.self]
    )
  }

  func testPOSTRequiresExplicitReturnType() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/users", body: "user")
      func createUser(user: User) async throws
      """,
      expandedSource: """
        func createUser(user: User) async throws
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@POST methods must have an explicit return type",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["POST": POSTMacro.self]
    )
  }

  func testPOSTBodyParameterNotFound() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/users", body: "userData")
      func createUser(user: User) async throws -> User
      """,
      expandedSource: """
        func createUser(user: User) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Body parameter 'userData' not found in function signature. \
            Available: [user]
            """,
          line: 1,
          column: 1
        )
      ],
      macros: ["POST": POSTMacro.self]
    )
  }

  func testPOSTPathParameterMismatch() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/users/{userId}", body: "user")
      func createUser(id: String, user: User) async throws -> User
      """,
      expandedSource: """
        func createUser(id: String, user: User) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Path parameter mismatch in '/users/{userId}': \
            function has parameters [id, user], \
            but path requires [userId]
            """,
          line: 1,
          column: 1
        )
      ],
      macros: ["POST": POSTMacro.self]
    )
  }

  func testPOSTQueryParameterNotFound() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/users", body: "user", queryParameters: ["notify", "email"])
      func createUser(user: User, notify: Bool) async throws -> User
      """,
      expandedSource: """
        func createUser(user: User, notify: Bool) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Query parameter 'email' not found in function signature. \
            Available: [user, notify]
            """,
          line: 1,
          column: 1
        )
      ],
      macros: ["POST": POSTMacro.self]
    )
  }
}
