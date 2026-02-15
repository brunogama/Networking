import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(NetworkingMacros)
import NetworkingMacros
#endif

/// Tests for @DELETE macro expansion.
final class DELETEMacroTests: XCTestCase {
  // MARK: - Success Cases

  func testDELETEBasicExpansion() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DELETE("/users/{id}")
      func deleteUser(id: String) async throws
      """,
      expandedSource: """
        func deleteUser(id: String) async throws

        func deleteUser(id: String) async throws {
          let path = "/users/\\(id)"
          var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)
          let _ = try await client.execute(request)
        }
        """,
      macros: ["DELETE": DELETEMacro.self]
    )
  }

  func testDELETEWithReturnType() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DELETE("/users/{id}")
      func deleteUser(id: String) async throws -> DeleteResponse
      """,
      expandedSource: """
        func deleteUser(id: String) async throws -> DeleteResponse

        func deleteUser(id: String) async throws -> DeleteResponse {
          let path = "/users/\\(id)"
          var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)
          let response = try await client.execute(request)
          return try JSONDecoder().decode(DeleteResponse.self, from: response.data)
        }
        """,
      macros: ["DELETE": DELETEMacro.self]
    )
  }

  func testDELETEWithMultiplePathParameters() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DELETE("/teams/{teamId}/members/{memberId}")
      func removeMember(teamId: String, memberId: String) async throws
      """,
      expandedSource: """
        func removeMember(teamId: String, memberId: String) async throws

        func removeMember(teamId: String, memberId: String) async throws {
          let path = "/teams/\\(teamId)/members/\\(memberId)"
          var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)
          let _ = try await client.execute(request)
        }
        """,
      macros: ["DELETE": DELETEMacro.self]
    )
  }

  func testDELETEWithQueryParameters() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DELETE("/users/{id}", queryParameters: ["soft"])
      func deleteUser(id: String, soft: Bool) async throws
      """,
      expandedSource: """
        func deleteUser(id: String, soft: Bool) async throws

        func deleteUser(id: String, soft: Bool) async throws {
          let path = "/users/\\(id)"
          var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)
          request.addQueryParameter(name: "soft", value: \\(soft))
          let _ = try await client.execute(request)
        }
        """,
      macros: ["DELETE": DELETEMacro.self]
    )
  }

  func testDELETEWithQueryParametersAndReturnType() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DELETE("/resources/{id}", queryParameters: ["cascade"])
      func deleteResource(id: String, cascade: Bool) async throws -> DeletionResult
      """,
      expandedSource: """
        func deleteResource(id: String, cascade: Bool) async throws -> DeletionResult

        func deleteResource(id: String, cascade: Bool) async throws -> DeletionResult {
          let path = "/resources/\\(id)"
          var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)
          request.addQueryParameter(name: "cascade", value: \\(cascade))
          let response = try await client.execute(request)
          return try JSONDecoder().decode(DeletionResult.self, from: response.data)
        }
        """,
      macros: ["DELETE": DELETEMacro.self]
    )
  }

  func testDELETEWithCustomHeaders() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DELETE("/users/{id}", headers: ["X-Request-ID": "12345", "Authorization": "Bearer token"])
      func deleteUser(id: String) async throws
      """,
      expandedSource: """
        func deleteUser(id: String) async throws

        func deleteUser(id: String) async throws {
          let path = "/users/\\(id)"
          var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)
          request.addHeader(name: "Authorization", value: "Bearer token")
          request.addHeader(name: "X-Request-ID", value: "12345")
          let _ = try await client.execute(request)
        }
        """,
      macros: ["DELETE": DELETEMacro.self]
    )
  }

  // MARK: - Error Cases

  func testDELETERequiresAsyncThrows() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DELETE("/users/{id}")
      func deleteUser(id: String)
      """,
      expandedSource: """
        func deleteUser(id: String)
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Function 'deleteUser' must be marked 'async'",
          line: 1,
          column: 1
        )
      ],
      macros: ["DELETE": DELETEMacro.self]
    )
  }

  func testDELETERequiresPath() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DELETE
      func deleteUser(id: String) async throws
      """,
      expandedSource: """
        func deleteUser(id: String) async throws
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@DELETE requires a path argument",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["DELETE": DELETEMacro.self]
    )
  }

  func testDELETEPathParameterMismatch() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DELETE("/users/{userId}")
      func deleteUser(id: String) async throws
      """,
      expandedSource: """
        func deleteUser(id: String) async throws
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Path parameter mismatch in '/users/{userId}': \
            function has parameters [id], \
            but path requires [userId]
            """,
          line: 1,
          column: 1
        )
      ],
      macros: ["DELETE": DELETEMacro.self]
    )
  }

  func testDELETEQueryParameterNotFound() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DELETE("/users/{id}", queryParameters: ["soft", "cascade"])
      func deleteUser(id: String, soft: Bool) async throws
      """,
      expandedSource: """
        func deleteUser(id: String, soft: Bool) async throws
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Query parameter 'cascade' not found in function signature. \
            Available: [id, soft]
            """,
          line: 1,
          column: 1
        )
      ],
      macros: ["DELETE": DELETEMacro.self]
    )
  }
}
