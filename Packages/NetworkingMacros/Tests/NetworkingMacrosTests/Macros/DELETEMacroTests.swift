import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for @DELETE using MacroTesting framework.
///
/// Tests validate that DELETEMacro generates correct HTTP method implementations
/// with proper Void return type handling and no body requirements.
final class DELETEMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(macros: [DELETEMacro.self]) {
      super.invokeTest()
    }
  }

  // MARK: - Basic Expansion Tests

  func testBasicDELETEExpansion() {
    assertMacro {
      """
      @DELETE("/users/{id}")
      func deleteUser(id: String) async throws
      """
    } expansion: {
      #"""
      func deleteUser(id: String) async throws

      func deleteUser(id: String) async throws -> Void {
          let path = "/users/\(id)"
          var request = HTTPRequest(method nil .DELETE, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode(Void.self, from response.data)
      }
      """#
    }
  }

  func testDELETEWithPathParameter() {
    assertMacro {
      """
      @DELETE("/projects/{projectId}/tasks/{taskId}")
      func deleteTask(projectId: String, taskId: String) async throws
      """
    } expansion: {
      #"""
      func deleteTask(projectId: String, taskId: String) async throws

      func deleteTask(projectId: String taskId: String) async throws -> Void {
          let path = "/projects/\(projectId)/tasks/\(taskId)"
          var request = HTTPRequest(method nil .DELETE, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode(Void.self, from response.data)
      }
      """#
    }
  }

  func testDELETEVoidReturn() {
    assertMacro {
      """
      @DELETE("/cache")
      func clearCache() async throws
      """
    } expansion: {
      """
      func clearCache() async throws

      func clearCache() async throws -> Void {
          let path = "/cache"
          var request = HTTPRequest(method nil .DELETE, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode(Void.self, from response.data)
      }
      """
    }
  }

  // MARK: - Diagnostic Tests

  func testDELETERequiresPath() {
    assertMacro {
      """
      @DELETE
      func deleteUser(id: String) async throws
      """
    } diagnostics: {
      """
      @DELETE
      ┬──────
      ╰─ 🛑 @DELETE requires a path argument
      func deleteUser(id: String) async throws
      """
    }
  }

  func testDELETERequiresAsyncThrows() {
    assertMacro {
      """
      @DELETE("/users/{id}")
      func deleteUser(id: String)
      """
    } diagnostics: {
      """
      @DELETE("/users/{id}")
      ┬─────────────────────
      ╰─ 🛑 Function 'deleteUser' must be marked 'async'
      func deleteUser(id: String)
      """
    }
  }

  func testDELETEValidatesPathParameters() {
    assertMacro {
      """
      @DELETE("/users/{userId}")
      func deleteUser(id: String) async throws
      """
    } diagnostics: {
      """
      @DELETE("/users/{userId}")
      ┬─────────────────────────
      ╰─ 🛑 Path parameter mismatch in '/users/{userId}': function has parameters [id], but path requires [userId]
      func deleteUser(id: String) async throws
      """
    }
  }
}
