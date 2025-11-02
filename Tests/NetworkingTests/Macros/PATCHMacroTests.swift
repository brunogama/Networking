import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import NetworkingMacros

/// Tests for @PATCH macro expansion.
final class PATCHMacroTests: XCTestCase {
  // MARK: - Success Cases

  func testPATCHBasicExpansion() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH("/users/{id}", body: "updates")
      func patchUser(id: String, updates: UserUpdate) async throws -> User
      """,
      expandedSource: """
        func patchUser(id: String, updates: UserUpdate) async throws -> User

        func patchUser(id: String, updates: UserUpdate) async throws -> User {
          let path = "/users/\\(id)"
          var request = HTTPRequest(method: .PATCH, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(updates))
          request.addHeader(name: "Content-Type", value: "application/json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      macros: ["PATCH": PATCHMacro.self]
    )
  }

  func testPATCHWithMultiplePathParameters() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH("/projects/{projectId}/tasks/{taskId}", body: "updates")
      func updateTask(projectId: String, taskId: String, updates: TaskUpdate) async throws -> Task
      """,
      expandedSource: """
        func updateTask(projectId: String, taskId: String, updates: TaskUpdate) async throws -> Task

        func updateTask(projectId: String, taskId: String, updates: TaskUpdate) async throws -> Task {
          let path = "/projects/\\(projectId)/tasks/\\(taskId)"
          var request = HTTPRequest(method: .PATCH, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(updates))
          request.addHeader(name: "Content-Type", value: "application/json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(Task.self, from: response.data)
        }
        """,
      macros: ["PATCH": PATCHMacro.self]
    )
  }

  func testPATCHWithQueryParameters() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH("/users/{id}", body: "updates", queryParameters: ["partial"])
      func patchUser(id: String, updates: UserUpdate, partial: Bool) async throws -> User
      """,
      expandedSource: """
        func patchUser(id: String, updates: UserUpdate, partial: Bool) async throws -> User

        func patchUser(id: String, updates: UserUpdate, partial: Bool) async throws -> User {
          let path = "/users/\\(id)"
          var request = HTTPRequest(method: .PATCH, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(updates))
          request.addHeader(name: "Content-Type", value: "application/json")
          request.addQueryParameter(name: "partial", value: \\(partial))
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      macros: ["PATCH": PATCHMacro.self]
    )
  }

  func testPATCHWithCustomHeaders() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH("/users/{id}", body: "updates", headers: ["If-Match": "etag456"])
      func patchUser(id: String, updates: UserUpdate) async throws -> User
      """,
      expandedSource: """
        func patchUser(id: String, updates: UserUpdate) async throws -> User

        func patchUser(id: String, updates: UserUpdate) async throws -> User {
          let path = "/users/\\(id)"
          var request = HTTPRequest(method: .PATCH, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(updates))
          request.addHeader(name: "Content-Type", value: "application/json")
          request.addHeader(name: "If-Match", value: "etag456")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      macros: ["PATCH": PATCHMacro.self]
    )
  }

  func testPATCHWithAllFeatures() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH("/teams/{teamId}/members/{memberId}", body: "updates", queryParameters: ["merge"], headers: ["X-Audit-User": "admin"])
      func updateMember(teamId: String, memberId: String, updates: MemberUpdate, merge: Bool) async throws -> Member
      """,
      expandedSource: """
        func updateMember(teamId: String, memberId: String, updates: MemberUpdate, merge: Bool) async throws -> Member

        func updateMember(teamId: String, memberId: String, updates: MemberUpdate, merge: Bool) async throws -> Member {
          let path = "/teams/\\(teamId)/members/\\(memberId)"
          var request = HTTPRequest(method: .PATCH, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(updates))
          request.addHeader(name: "Content-Type", value: "application/json")
          request.addHeader(name: "X-Audit-User", value: "admin")
          request.addQueryParameter(name: "merge", value: \\(merge))
          let response = try await client.execute(request)
          return try JSONDecoder().decode(Member.self, from: response.data)
        }
        """,
      macros: ["PATCH": PATCHMacro.self]
    )
  }

  // MARK: - Error Cases

  func testPATCHRequiresAsyncThrows() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH("/users/{id}", body: "updates")
      func patchUser(id: String, updates: UserUpdate) -> User
      """,
      expandedSource: """
        func patchUser(id: String, updates: UserUpdate) -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Function 'patchUser' must be marked 'async'",
          line: 1,
          column: 1
        )
      ],
      macros: ["PATCH": PATCHMacro.self]
    )
  }

  func testPATCHRequiresPath() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH
      func patchUser(id: String, updates: UserUpdate) async throws -> User
      """,
      expandedSource: """
        func patchUser(id: String, updates: UserUpdate) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@PATCH requires a path argument",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["PATCH": PATCHMacro.self]
    )
  }

  func testPATCHRequiresBodyParameter() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH("/users/{id}")
      func patchUser(id: String, updates: UserUpdate) async throws -> User
      """,
      expandedSource: """
        func patchUser(id: String, updates: UserUpdate) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@PATCH requires a 'body' argument",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["PATCH": PATCHMacro.self]
    )
  }

  func testPATCHRequiresExplicitReturnType() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH("/users/{id}", body: "updates")
      func patchUser(id: String, updates: UserUpdate) async throws
      """,
      expandedSource: """
        func patchUser(id: String, updates: UserUpdate) async throws
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@PATCH methods must have an explicit return type",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["PATCH": PATCHMacro.self]
    )
  }

  func testPATCHBodyParameterNotFound() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH("/users/{id}", body: "changes")
      func patchUser(id: String, updates: UserUpdate) async throws -> User
      """,
      expandedSource: """
        func patchUser(id: String, updates: UserUpdate) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Body parameter 'changes' not found in function signature. \
            Available: [id, updates]
            """,
          line: 1,
          column: 1
        )
      ],
      macros: ["PATCH": PATCHMacro.self]
    )
  }

  func testPATCHPathParameterMismatch() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH("/users/{userId}", body: "updates")
      func patchUser(id: String, updates: UserUpdate) async throws -> User
      """,
      expandedSource: """
        func patchUser(id: String, updates: UserUpdate) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Path parameter mismatch in '/users/{userId}': \
            function has parameters [id, updates], \
            but path requires [userId]
            """,
          line: 1,
          column: 1
        )
      ],
      macros: ["PATCH": PATCHMacro.self]
    )
  }

  func testPATCHQueryParameterNotFound() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH("/users/{id}", body: "updates", queryParameters: ["merge", "validate"])
      func patchUser(id: String, updates: UserUpdate, merge: Bool) async throws -> User
      """,
      expandedSource: """
        func patchUser(id: String, updates: UserUpdate, merge: Bool) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Query parameter 'validate' not found in function signature. \
            Available: [id, updates, merge]
            """,
          line: 1,
          column: 1
        )
      ],
      macros: ["PATCH": PATCHMacro.self]
    )
  }
}
