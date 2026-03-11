import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for @PUT using MacroTesting framework.
///
/// Tests validate that PUTMacro generates correct HTTP method implementations
/// with proper body handling for resource updates.
final class PUTMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(macros: [PUTMacro.self]) {
      super.invokeTest()
    }
  }

  // MARK: - Basic Expansion Tests

  func testBasicPUTExpansion() {
    assertMacro {
      """
      @PUT(.path("/users/{id}"))
      @Body(.parameter("user"))
      func updateUser(id: String, user: User) async throws -> User
      """
    } expansion: {
      #"""
      @Body(.parameter("user"))
      func updateUser(id: String, user: User) async throws -> User

      func updateUser(id: String user: User) async throws -> User {
          let path = "/users/\(id)"
          var request = HTTPRequest(method nil .PUT, path path, baseURL baseURL)

        request.setBody(try JSONEncoder().encode(user))
        request.addHeader(name: "Content-Type", value: "application/json")
          let response = client.execute(request)
          return JSONDecoder().decode(User.self, from response.data)
      }
      """#
    }
  }

  func testPUTWithMultiplePathParameters() {
    assertMacro {
      """
      @PUT(.path("/projects/{projectId}/tasks/{taskId}"))
      @Body(.parameter("task"))
      func updateTask(projectId: String, taskId: String, task: Task) async throws -> Task
      """
    } expansion: {
      #"""
      @Body(.parameter("task"))
      func updateTask(projectId: String, taskId: String, task: Task) async throws -> Task

      func updateTask(projectId: String taskId: String task: Task) async throws -> Task {
          let path = "/projects/\(projectId)/tasks/\(taskId)"
          var request = HTTPRequest(method nil .PUT, path path, baseURL baseURL)

        request.setBody(try JSONEncoder().encode(task))
        request.addHeader(name: "Content-Type", value: "application/json")
          let response = client.execute(request)
          return JSONDecoder().decode(Task.self, from response.data)
      }
      """#
    }
  }

  func testPUTWithAllParameters() {
    assertMacro {
      """
      @PUT(.path("/users/{id}"), query: [.parameter("notify")])
      @Body(.parameter("user"))
      func updateUser(id: String, user: User, notify: Bool) async throws -> User
      """
    } expansion: {
      #"""
      @Body(.parameter("user"))
      func updateUser(id: String, user: User, notify: Bool) async throws -> User

      func updateUser(id: String user: User notify: Bool) async throws -> User {
          let path = "/users/\(id)"
          var request = HTTPRequest(method nil .PUT, path path, baseURL baseURL)

        request.setBody(try JSONEncoder().encode(user))
        request.addHeader(name: "Content-Type", value: "application/json")
          let response = client.execute(request)
          return JSONDecoder().decode(User.self, from response.data)
      }
      """#
    }
  }

  // MARK: - Diagnostic Tests

  func testPUTRequiresBody() {
    assertMacro {
      """
      @PUT(.path("/users/{id}"))
      func updateUser(id: String, user: User) async throws -> User
      """
    } diagnostics: {
      """
      @PUT(.path("/users/{id}"))
      ┬─────────────────────────
      ╰─ 🛑 @PUT requires a body parameter. Use @Body("paramName") macro.
      func updateUser(id: String, user: User) async throws -> User
      """
    }
  }

  func testPUTRequiresAsyncThrows() {
    assertMacro {
      """
      @PUT(.path("/users/{id}"))
      @Body(.parameter("user"))
      func updateUser(id: String, user: User) -> User
      """
    } diagnostics: {
      """
      @PUT(.path("/users/{id}"))
      ┬─────────────────────────
      ╰─ 🛑 Function 'updateUser' must be marked 'async'
      @Body(.parameter("user"))
      func updateUser(id: String, user: User) -> User
      """
    }
  }
}
