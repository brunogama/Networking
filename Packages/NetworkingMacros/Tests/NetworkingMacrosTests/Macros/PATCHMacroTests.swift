import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for @PATCH using MacroTesting framework.
///
/// Tests validate that PATCHMacro generates correct HTTP method implementations
/// with proper body handling for partial resource updates.
final class PATCHMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(macros: [PATCHMacro.self]) {
      super.invokeTest()
    }
  }

  // MARK: - Basic Expansion Tests

  func testBasicPATCHExpansion() {
    assertMacro {
      """
      @PATCH("/users/{id}")
      @Body("patch")
      func patchUser(id: String, patch: UserPatch) async throws -> User
      """
    } expansion: {
      #"""
      @Body("patch")
      func patchUser(id: String, patch: UserPatch) async throws -> User

      func patchUser(id: String patch: UserPatch) async throws -> User {
          let path = "/users/\(id)"
          var request = HTTPRequest(method nil .PATCH, path path, baseURL baseURL)

        request.setBody(try JSONEncoder().encode(patch))
        request.addHeader(name: "Content-Type", value: "application/json")
          let response = client.execute(request)
          return JSONDecoder().decode(User.self, from response.data)
      }
      """#
    }
  }

  func testPATCHWithMultiplePathParameters() {
    assertMacro {
      """
      @PATCH("/projects/{projectId}/tasks/{taskId}")
      @Body("update")
      func patchTask(projectId: String, taskId: String, update: TaskPatch) async throws -> Task
      """
    } expansion: {
      #"""
      @Body("update")
      func patchTask(projectId: String, taskId: String, update: TaskPatch) async throws -> Task

      func patchTask(projectId: String taskId: String update: TaskPatch) async throws -> Task {
          let path = "/projects/\(projectId)/tasks/\(taskId)"
          var request = HTTPRequest(method nil .PATCH, path path, baseURL baseURL)

        request.setBody(try JSONEncoder().encode(update))
        request.addHeader(name: "Content-Type", value: "application/json")
          let response = client.execute(request)
          return JSONDecoder().decode(Task.self, from response.data)
      }
      """#
    }
  }

  func testPATCHPartialUpdate() {
    assertMacro {
      """
      @PATCH("/settings/{key}")
      @Body("value")
      func updateSetting(key: String, value: SettingValue) async throws -> Setting
      """
    } expansion: {
      #"""
      @Body("value")
      func updateSetting(key: String, value: SettingValue) async throws -> Setting

      func updateSetting(key: String value: SettingValue) async throws -> Setting {
          let path = "/settings/\(key)"
          var request = HTTPRequest(method nil .PATCH, path path, baseURL baseURL)

        request.setBody(try JSONEncoder().encode(value))
        request.addHeader(name: "Content-Type", value: "application/json")
          let response = client.execute(request)
          return JSONDecoder().decode(Setting.self, from response.data)
      }
      """#
    }
  }

  // MARK: - Diagnostic Tests

  func testPATCHRequiresBody() {
    assertMacro {
      """
      @PATCH("/users/{id}")
      func patchUser(id: String, patch: UserPatch) async throws -> User
      """
    } diagnostics: {
      """
      @PATCH("/users/{id}")
      ┬────────────────────
      ╰─ 🛑 @PATCH requires a body parameter. Use @Body("paramName") macro.
      func patchUser(id: String, patch: UserPatch) async throws -> User
      """
    }
  }

  func testPATCHRequiresAsyncThrows() {
    assertMacro {
      """
      @PATCH("/users/{id}")
      @Body("patch")
      func patchUser(id: String, patch: UserPatch) -> User
      """
    } diagnostics: {
      """
      @PATCH("/users/{id}")
      ┬────────────────────
      ╰─ 🛑 Function 'patchUser' must be marked 'async'
      @Body("patch")
      func patchUser(id: String, patch: UserPatch) -> User
      """
    }
  }
}
