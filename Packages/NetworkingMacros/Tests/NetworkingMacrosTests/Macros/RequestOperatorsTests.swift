import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for request operator patterns.
///
/// Tests validate that macros generate correct HTTPRequest structures,
/// response handling, error handling, and request modification patterns.
final class RequestOperatorsTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      macros: [
        GETMacro.self,
        POSTMacro.self,
        DELETEMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  // MARK: - Basic Request Structure

  func testGETRequestStructure() {
    assertMacro {
      """
      @GET("/users/{id}")
      func getUser(id: String) async throws -> User
      """
    } expansion: {
      #"""
      func getUser(id: String) async throws -> User

      func getUser(id: String) async throws -> User {
          let path = "/users/\(id)"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode(User.self, from response.data)
      }
      """#
    }
  }

  func testPOSTRequestStructure() {
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

  func testDELETERequestStructure() {
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

  // MARK: - Response Handling Patterns

  func testDecodeResponsePattern() {
    assertMacro {
      """
      @GET("/users/{id}")
      func getUser(id: String) async throws -> User
      """
    } expansion: {
      #"""
      func getUser(id: String) async throws -> User

      func getUser(id: String) async throws -> User {
          let path = "/users/\(id)"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode(User.self, from response.data)
      }
      """#
    }
  }

  func testVoidReturnPattern() {
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

  func testArrayReturnPattern() {
    assertMacro {
      """
      @GET("/users")
      func listUsers() async throws -> [User]
      """
    } expansion: {
      """
      func listUsers() async throws -> [User]

      func listUsers() async throws -> [User] {
          let path = "/users"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode([User].self, from response.data)
      }
      """
    }
  }

  // MARK: - Error Handling Patterns

  func testAsyncThrowsSignature() {
    assertMacro {
      """
      @GET("/users")
      func getUsers() async throws -> [User]
      """
    } expansion: {
      """
      func getUsers() async throws -> [User]

      func getUsers() async throws -> [User] {
          let path = "/users"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode([User].self, from response.data)
      }
      """
    }
  }

  func testRequiresAsyncThrows() {
    assertMacro {
      """
      @GET("/users")
      func getUsers() -> [User]
      """
    } diagnostics: {
      """
      @GET("/users")
      ┬─────────────
      ╰─ 🛑 Function 'getUsers' must be marked 'async'
      func getUsers() -> [User]
      """
    }
  }

  // MARK: - Operator Chaining

  func testMultiplePathSegments() {
    assertMacro {
      """
      @GET("/api/v1/users/{userId}/profile")
      func getUserProfile(userId: String) async throws -> Profile
      """
    } expansion: {
      #"""
      func getUserProfile(userId: String) async throws -> Profile

      func getUserProfile(userId: String) async throws -> Profile {
          let path = "/api/v1/users/\(userId)/profile"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode(Profile.self, from response.data)
      }
      """#
    }
  }

  func testQueryParameterEncoding() {
    assertMacro {
      """
      @GET("/search", query: ["q", "page", "limit"])
      func search(q: String, page: Int, limit: Int) async throws -> SearchResults
      """
    } expansion: {
      """
      func search(q: String, page: Int, limit: Int) async throws -> SearchResults

      func search(q: String page: Int limit: Int) async throws -> SearchResults {
          let path = "/search"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode(SearchResults.self, from response.data)
      }
      """
    }
  }

  // MARK: - Complex Composition

  func testComplexRequestComposition() {
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
}
