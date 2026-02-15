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
      @POST("/users")
      @Body("user")
      func createUser(user: CreateUserRequest) async throws -> User
      """
    } expansion: {
      """
      @Body("user")
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
      @POST("/users/{id}/profile")
      @Body("profile")
      func updateProfile(id: String, profile: Profile) async throws -> Profile
      """
    } expansion: {
      #"""
      @Body("profile")
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
      @POST("/users", query: ["notify"])
      @Body("user")
      func createUser(user: CreateUserRequest, notify: Bool) async throws -> User
      """
    } expansion: {
      """
      @Body("user")
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
      @POST("/projects/{projectId}/tasks", query: ["priority"])
      @Body("task")
      func createTask(projectId: String, task: TaskRequest, priority: Int) async throws -> Task
      """
    } expansion: {
      #"""
      @Body("task")
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
      @POST("/users")
      func createUser(user: CreateUserRequest) async throws -> User
      """
    } diagnostics: {
      """
      @POST("/users")
      ┬──────────────
      ╰─ 🛑 @POST requires a body parameter. Use @Body("paramName") macro.
      func createUser(user: CreateUserRequest) async throws -> User
      """
    }
  }

  func testPOSTRequiresAsyncThrows() {
    assertMacro {
      """
      @POST("/users")
      @Body("user")
      func createUser(user: CreateUserRequest) -> User
      """
    } diagnostics: {
      """
      @POST("/users")
      ┬──────────────
      ╰─ 🛑 Function 'createUser' must be marked 'async'
      @Body("user")
      func createUser(user: CreateUserRequest) -> User
      """
    }
  }

  func testPOSTValidatesPathParameters() {
    assertMacro {
      """
      @POST("/users/{userId}/posts")
      @Body("post")
      func createPost(id: String, post: Post) async throws -> Post
      """
    } diagnostics: {
      """
      @POST("/users/{userId}/posts")
      ┬─────────────────────────────
      ╰─ 🛑 Path parameter mismatch in '/users/{userId}/posts': function has parameters [id, post], but path requires [userId]
      @Body("post")
      func createPost(id: String, post: Post) async throws -> Post
      """
    }
  }
}
