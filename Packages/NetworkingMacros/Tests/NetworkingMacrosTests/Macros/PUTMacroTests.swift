import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(NetworkingMacros)
import NetworkingMacros
#endif

/// Tests for @PUT macro expansion.
final class PUTMacroTests: XCTestCase {
  // MARK: - Success Cases

  func testPUTBasicExpansion() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PUT("/users/{id}", body: "user")
      func updateUser(id: String, user: User) async throws -> User
      """,
      expandedSource: """
        func updateUser(id: String, user: User) async throws -> User

        func updateUser(id: String, user: User) async throws -> User {
          let path = "/users/\\(id)"
          var request = HTTPRequest(method: .PUT, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(user))
          request.addHeader(name: "Content-Type", value: "application/json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      macros: ["PUT": PUTMacro.self]
    )
  }

  func testPUTWithMultiplePathParameters() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PUT("/teams/{teamId}/users/{userId}", body: "user")
      func updateTeamUser(teamId: String, userId: String, user: User) async throws -> User
      """,
      expandedSource: """
        func updateTeamUser(teamId: String, userId: String, user: User) async throws -> User

        func updateTeamUser(teamId: String, userId: String, user: User) async throws -> User {
          let path = "/teams/\\(teamId)/users/\\(userId)"
          var request = HTTPRequest(method: .PUT, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(user))
          request.addHeader(name: "Content-Type", value: "application/json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      macros: ["PUT": PUTMacro.self]
    )
  }

  func testPUTWithQueryParameters() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PUT("/users/{id}", body: "user", queryParameters: ["version"])
      func updateUser(id: String, user: User, version: Int) async throws -> User
      """,
      expandedSource: """
        func updateUser(id: String, user: User, version: Int) async throws -> User

        func updateUser(id: String, user: User, version: Int) async throws -> User {
          let path = "/users/\\(id)"
          var request = HTTPRequest(method: .PUT, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(user))
          request.addHeader(name: "Content-Type", value: "application/json")
          request.addQueryParameter(name: "version", value: \\(version))
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      macros: ["PUT": PUTMacro.self]
    )
  }

  func testPUTWithCustomHeaders() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PUT("/users/{id}", body: "user", headers: ["If-Match": "etag123"])
      func updateUser(id: String, user: User) async throws -> User
      """,
      expandedSource: """
        func updateUser(id: String, user: User) async throws -> User

        func updateUser(id: String, user: User) async throws -> User {
          let path = "/users/\\(id)"
          var request = HTTPRequest(method: .PUT, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(user))
          request.addHeader(name: "Content-Type", value: "application/json")
          request.addHeader(name: "If-Match", value: "etag123")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      macros: ["PUT": PUTMacro.self]
    )
  }

  // MARK: - Error Cases

  func testPUTRequiresAsyncThrows() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PUT("/users/{id}", body: "user")
      func updateUser(id: String, user: User) -> User
      """,
      expandedSource: """
        func updateUser(id: String, user: User) -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Function 'updateUser' must be marked 'async'",
          line: 1,
          column: 1
        )
      ],
      macros: ["PUT": PUTMacro.self]
    )
  }

  func testPUTRequiresPath() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PUT
      func updateUser(id: String, user: User) async throws -> User
      """,
      expandedSource: """
        func updateUser(id: String, user: User) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@PUT requires a path argument",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["PUT": PUTMacro.self]
    )
  }

  func testPUTRequiresBodyParameter() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PUT("/users/{id}")
      func updateUser(id: String, user: User) async throws -> User
      """,
      expandedSource: """
        func updateUser(id: String, user: User) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@PUT requires a 'body' argument",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["PUT": PUTMacro.self]
    )
  }

  func testPUTRequiresExplicitReturnType() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PUT("/users/{id}", body: "user")
      func updateUser(id: String, user: User) async throws
      """,
      expandedSource: """
        func updateUser(id: String, user: User) async throws
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@PUT methods must have an explicit return type",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["PUT": PUTMacro.self]
    )
  }

  func testPUTBodyParameterNotFound() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PUT("/users/{id}", body: "updates")
      func updateUser(id: String, user: User) async throws -> User
      """,
      expandedSource: """
        func updateUser(id: String, user: User) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Body parameter 'updates' not found in function signature. \
            Available: [id, user]
            """,
          line: 1,
          column: 1
        )
      ],
      macros: ["PUT": PUTMacro.self]
    )
  }

  func testPUTPathParameterMismatch() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PUT("/users/{userId}", body: "user")
      func updateUser(id: String, user: User) async throws -> User
      """,
      expandedSource: """
        func updateUser(id: String, user: User) async throws -> User
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
      macros: ["PUT": PUTMacro.self]
    )
  }
}
