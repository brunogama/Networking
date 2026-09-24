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
      @PATCH(.path("/users/{id}"))
      @Body(.parameter("patch"))
      func patchUser(id: String, patch: UserPatch) async throws -> User
      """
    } expansion: {
      #"""
      @Body(.parameter("patch"))
      func patchUser(id: String, patch: UserPatch) async throws -> User

      func patchUser(id: String, patch: UserPatch) async throws -> User {
        let path = "/users/\(id)"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        var request = HTTPRequest(
          method: .patch,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        request.setBody(HTTPBody(try JSONEncoder().encode(patch)))
        request.addHeader(name: "Content-Type", value: "application/json")
        let response = try await client.execute(request)
        guard let responseBody = response.body else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
          )
        }
        return try JSONDecoder().decode(User.self, from: responseBody.rawValue)
      }
      """#
    }
  }

  func testPATCHWithMultiplePathParameters() {
    assertMacro {
      """
      @PATCH(.path("/projects/{projectId}/tasks/{taskId}"))
      @Body(.parameter("update"))
      func patchTask(projectId: String, taskId: String, update: TaskPatch) async throws -> Task
      """
    } expansion: {
      #"""
      @Body(.parameter("update"))
      func patchTask(projectId: String, taskId: String, update: TaskPatch) async throws -> Task

      func patchTask(projectId: String, taskId: String, update: TaskPatch) async throws -> Task {
        let path = "/projects/\(projectId)/tasks/\(taskId)"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        var request = HTTPRequest(
          method: .patch,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        request.setBody(HTTPBody(try JSONEncoder().encode(update)))
        request.addHeader(name: "Content-Type", value: "application/json")
        let response = try await client.execute(request)
        guard let responseBody = response.body else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
          )
        }
        return try JSONDecoder().decode(Task.self, from: responseBody.rawValue)
      }
      """#
    }
  }

  func testPATCHPartialUpdate() {
    assertMacro {
      """
      @PATCH(.path("/settings/{key}"))
      @Body(.parameter("value"))
      func updateSetting(key: String, value: SettingValue) async throws -> Setting
      """
    } expansion: {
      #"""
      @Body(.parameter("value"))
      func updateSetting(key: String, value: SettingValue) async throws -> Setting

      func updateSetting(key: String, value: SettingValue) async throws -> Setting {
        let path = "/settings/\(key)"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        var request = HTTPRequest(
          method: .patch,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        request.setBody(HTTPBody(try JSONEncoder().encode(value)))
        request.addHeader(name: "Content-Type", value: "application/json")
        let response = try await client.execute(request)
        guard let responseBody = response.body else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
          )
        }
        return try JSONDecoder().decode(Setting.self, from: responseBody.rawValue)
      }
      """#
    }
  }

  // MARK: - Diagnostic Tests

  func testPATCHRequiresBody() {
    assertMacro {
      """
      @PATCH(.path("/users/{id}"))
      func patchUser(id: String, patch: UserPatch) async throws -> User
      """
    } diagnostics: {
      """
      @PATCH(.path("/users/{id}"))
      ┬───────────────────────────
      ╰─ 🛑 @PATCH requires a body parameter. Use @Body("paramName") macro.
      func patchUser(id: String, patch: UserPatch) async throws -> User
      """
    }
  }

  func testPATCHRequiresAsyncThrows() {
    assertMacro {
      """
      @PATCH(.path("/users/{id}"))
      @Body(.parameter("patch"))
      func patchUser(id: String, patch: UserPatch) -> User
      """
    } diagnostics: {
      """
      @PATCH(.path("/users/{id}"))
      ┬───────────────────────────
      ╰─ 🛑 Function 'patchUser' must be marked 'async'
      @Body(.parameter("patch"))
      func patchUser(id: String, patch: UserPatch) -> User
      """
    }
  }
}
