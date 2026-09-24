// swiftlint:disable line_length
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
      @DELETE(.path("/users/{id}"))
      func deleteUser(id: String) async throws
      """
    } expansion: {
      #"""
      func deleteUser(id: String) async throws

      func deleteUser(id: String) async throws {
        let path = "/users/\(id)"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        let request = HTTPRequest(
          method: .delete,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        _ = try await client.execute(request)
        return
      }
      """#
    }
  }

  func testDELETEWithPathParameter() {
    assertMacro {
      """
      @DELETE(.path("/projects/{projectId}/tasks/{taskId}"))
      func deleteTask(projectId: String, taskId: String) async throws
      """
    } expansion: {
      #"""
      func deleteTask(projectId: String, taskId: String) async throws

      func deleteTask(projectId: String, taskId: String) async throws {
        let path = "/projects/\(projectId)/tasks/\(taskId)"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        let request = HTTPRequest(
          method: .delete,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        _ = try await client.execute(request)
        return
      }
      """#
    }
  }

  func testDELETEVoidReturn() {
    assertMacro {
      """
      @DELETE(.path("/cache"))
      func clearCache() async throws
      """
    } expansion: {
      """
      func clearCache() async throws

      func clearCache() async throws {
        let path = "/cache"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        let request = HTTPRequest(
          method: .delete,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        _ = try await client.execute(request)
        return
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
      @DELETE(.path("/users/{id}"))
      func deleteUser(id: String)
      """
    } diagnostics: {
      """
      @DELETE(.path("/users/{id}"))
      ┬────────────────────────────
      ╰─ 🛑 Function 'deleteUser' must be marked 'async'
      func deleteUser(id: String)
      """
    }
  }

  func testDELETEValidatesPathParameters() {
    assertMacro {
      """
      @DELETE(.path("/users/{userId}"))
      func deleteUser(id: String) async throws
      """
    } diagnostics: {
      """
      @DELETE(.path("/users/{userId}"))
      ┬────────────────────────────────
      ╰─ 🛑 Path parameter mismatch in '/users/{userId}': function has parameters [id], but path requires [userId]
      func deleteUser(id: String) async throws
      """
    }
  }
}
// swiftlint:enable line_length
