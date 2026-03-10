import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for @POST using MacroTesting framework.
///
/// Tests validate that POSTMacro generates correct HTTP method implementations
/// with proper body handling, path parameters, and query parameters.
final class POSTMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(macros: [POSTMacro.self]) {
      super.invokeTest()
    }
  }

  // MARK: - Basic Expansion Tests

  func testBasicPOSTExpansion() {
    assertMacro {
      """
      @POST(.path("/users"))
      @Body(.parameter("user"))
      func createUser(user: CreateUserRequest) async throws -> User
      """
    } expansion: {
      """
      @Body(.parameter("user"))
      func createUser(user: CreateUserRequest) async throws -> User

      func createUser(user: CreateUserRequest) async throws -> User {
          let path = "/users"
          var request = HTTPRequest(method nil .POST, path path, baseURL baseURL)

        request.setBody(try JSONEncoder().encode(user))
        request.addHeader(name: "Content-Type", value: "application/json")
          let response = client.execute(request)
          return JSONDecoder().decode(User.self, from response.data)
      }
      """
    }
  }

  func testPOSTWithPathParameter() {
    assertMacro {
      """
      @POST(.path("/users/{id}/profile"))
      @Body(.parameter("profile"))
      func updateProfile(id: String, profile: Profile) async throws -> Profile
      """
    } expansion: {
      #"""
      @Body(.parameter("profile"))
      func updateProfile(id: String, profile: Profile) async throws -> Profile

      func updateProfile(id: String profile: Profile) async throws -> Profile {
          let path = "/users/\(id)/profile"
          var request = HTTPRequest(method nil .POST, path path, baseURL baseURL)

        request.setBody(try JSONEncoder().encode(profile))
        request.addHeader(name: "Content-Type", value: "application/json")
          let response = client.execute(request)
          return JSONDecoder().decode(Profile.self, from response.data)
      }
      """#
    }
  }

  func testPOSTWithQueryParameter() {
    assertMacro {
      """
      @POST(.path("/users"), query: [.parameter("notify")])
      @Body(.parameter("user"))
      func createUser(user: CreateUserRequest, notify: Bool) async throws -> User
      """
    } expansion: {
      """
      @Body(.parameter("user"))
      func createUser(user: CreateUserRequest, notify: Bool) async throws -> User

      func createUser(user: CreateUserRequest notify: Bool) async throws -> User {
          let path = "/users"
          var request = HTTPRequest(method nil .POST, path path, baseURL baseURL)

        request.setBody(try JSONEncoder().encode(user))
        request.addHeader(name: "Content-Type", value: "application/json")
          let response = client.execute(request)
          return JSONDecoder().decode(User.self, from response.data)
      }
      """
    }
  }

  func testPOSTWithAllParameters() {
    assertMacro {
      """
      @POST(.path("/projects/{projectId}/tasks"), query: [.parameter("priority")])
      @Body(.parameter("task"))
      func createTask(projectId: String, task: TaskRequest, priority: Int) async throws -> Task
      """
    } expansion: {
      #"""
      @Body(.parameter("task"))
      func createTask(projectId: String, task: TaskRequest, priority: Int) async throws -> Task

      func createTask(projectId: String task: TaskRequest priority: Int) async throws -> Task {
          let path = "/projects/\(projectId)/tasks"
          var request = HTTPRequest(method nil .POST, path path, baseURL baseURL)

        request.setBody(try JSONEncoder().encode(task))
        request.addHeader(name: "Content-Type", value: "application/json")
          let response = client.execute(request)
          return JSONDecoder().decode(Task.self, from response.data)
      }
      """#
    }
  }

  // MARK: - Diagnostic Tests

  func testPOSTRequiresBody() {
    assertMacro {
      """
      @POST(.path("/users"))
      func createUser(user: CreateUserRequest) async throws -> User
      """
    } diagnostics: {
      """
      @POST(.path("/users"))
      ┬─────────────────────
      ╰─ 🛑 @POST requires a body parameter. Use @Body("paramName") macro.
      func createUser(user: CreateUserRequest) async throws -> User
      """
    }
  }

  func testPOSTRequiresAsyncThrows() {
    assertMacro {
      """
      @POST(.path("/users"))
      @Body(.parameter("user"))
      func createUser(user: CreateUserRequest) -> User
      """
    } diagnostics: {
      """
      @POST(.path("/users"))
      ┬─────────────────────
      ╰─ 🛑 Function 'createUser' must be marked 'async'
      @Body(.parameter("user"))
      func createUser(user: CreateUserRequest) -> User
      """
    }
  }

  func testPOSTValidatesPathParameters() {
    assertMacro {
      """
      @POST(.path("/users/{userId}/posts"))
      @Body(.parameter("post"))
      func createPost(id: String, post: Post) async throws -> Post
      """
    } diagnostics: {
      """
      @POST(.path("/users/{userId}/posts"))
      ┬────────────────────────────────────
      ╰─ 🛑 Path parameter mismatch in '/users/{userId}/posts': function has parameters [id, post], but path requires [userId]
      @Body(.parameter("post"))
      func createPost(id: String, post: Post) async throws -> Post
      """
    }
  }
}
