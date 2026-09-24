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

      func updateUser(id: String, user: User) async throws -> User {
        let path = "/users/\(id)"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        var request = HTTPRequest(
          method: .put,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        request.setBody(HTTPBody(try JSONEncoder().encode(user)))
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

      func updateTask(projectId: String, taskId: String, task: Task) async throws -> Task {
        let path = "/projects/\(projectId)/tasks/\(taskId)"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        var request = HTTPRequest(
          method: .put,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        request.setBody(HTTPBody(try JSONEncoder().encode(task)))
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

  func testPUTWithAllParameters() {
    assertMacro {
      """
      @PUT(.path("/users/{id}"), queryParameters: [.parameter("notify")])
      @Body(.parameter("user"))
      func updateUser(id: String, user: User, notify: Bool) async throws -> User
      """
    } expansion: {
      #"""
      @Body(.parameter("user"))
      func updateUser(id: String, user: User, notify: Bool) async throws -> User

      func updateUser(id: String, user: User, notify: Bool) async throws -> User {
        let path = "/users/\(id)"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        var request = HTTPRequest(
          method: .put,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        request.setBody(HTTPBody(try JSONEncoder().encode(user)))
        request.addHeader(name: "Content-Type", value: "application/json")
        request.addQueryParameter(name: "notify", value: notify)
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
