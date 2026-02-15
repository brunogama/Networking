import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for @GET using MacroTesting framework.
///
/// Tests validate that GETMacro generates correct HTTP method implementations
/// with proper path handling, parameter validation, and code generation.
final class GETMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(macros: [GETMacro.self]) {
      super.invokeTest()
    }
  }

  // MARK: - Basic Expansion Tests

  func testBasicGETExpansion() {
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

  func testGETWithPathParameter() {
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

  func testGETWithMultiplePathParameters() {
    assertMacro {
      """
      @GET("/users/{userId}/posts/{postId}")
      func getPost(userId: String, postId: String) async throws -> Post
      """
    } expansion: {
      #"""
      func getPost(userId: String, postId: String) async throws -> Post

      func getPost(userId: String postId: String) async throws -> Post {
          let path = "/users/\(userId)/posts/\(postId)"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode(Post.self, from response.data)
      }
      """#
    }
  }

  // MARK: - Query Parameters

  func testGETWithQueryParameter() {
    assertMacro {
      """
      @GET("/users", query: ["page"])
      func listUsers(page: Int) async throws -> [User]
      """
    } expansion: {
      """
      func listUsers(page: Int) async throws -> [User]

      func listUsers(page: Int) async throws -> [User] {
          let path = "/users"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode([User].self, from response.data)
      }
      """
    }
  }

  // MARK: - Diagnostic Tests

  func testGETRequiresPath() {
    assertMacro {
      """
      @GET
      func getUsers() async throws -> [User]
      """
    } diagnostics: {
      """
      @GET
      ┬───
      ╰─ 🛑 @GET requires a path argument
      func getUsers() async throws -> [User]
      """
    }
  }

  func testGETRequiresAsyncThrows() {
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

  func testGETValidatesPathParameters() {
    assertMacro {
      """
      @GET("/users/{userId}")
      func getUser(id: String) async throws -> User
      """
    } diagnostics: {
      """
      @GET("/users/{userId}")
      ┬──────────────────────
      ╰─ 🛑 Path parameter mismatch in '/users/{userId}': function has parameters [id], but path requires [userId]
      func getUser(id: String) async throws -> User
      """
    }
  }
}
