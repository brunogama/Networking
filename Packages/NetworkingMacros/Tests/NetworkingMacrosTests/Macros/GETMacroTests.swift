// swiftlint:disable line_length
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
      @GET(.path("/users"))
      func getUsers() async throws -> [User]
      """
    } expansion: {
      """
      func getUsers() async throws -> [User]

      func getUsers() async throws -> [User] {
        let path = "/users"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        let request = HTTPRequest(
          method: .get,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        let response = try await client.execute(request)
        guard let responseBody = response.body else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
          )
        }
        return try JSONDecoder().decode([User].self, from: responseBody.rawValue)
      }
      """
    }
  }

  func testGETWithPathParameter() {
    assertMacro {
      """
      @GET(.path("/users/{id}"))
      func getUser(id: String) async throws -> User
      """
    } expansion: {
      #"""
      func getUser(id: String) async throws -> User

      func getUser(id: String) async throws -> User {
        let path = "/users/\(id)"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        let request = HTTPRequest(
          method: .get,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
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

  func testGETWithMultiplePathParameters() {
    assertMacro {
      """
      @GET(.path("/users/{userId}/posts/{postId}"))
      func getPost(userId: String, postId: String) async throws -> Post
      """
    } expansion: {
      #"""
      func getPost(userId: String, postId: String) async throws -> Post

      func getPost(userId: String, postId: String) async throws -> Post {
        let path = "/users/\(userId)/posts/\(postId)"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        let request = HTTPRequest(
          method: .get,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        let response = try await client.execute(request)
        guard let responseBody = response.body else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
          )
        }
        return try JSONDecoder().decode(Post.self, from: responseBody.rawValue)
      }
      """#
    }
  }

  // MARK: - Query Parameters

  func testGETWithQueryParameter() {
    assertMacro {
      """
      @GET(.path("/users"), queryParameters: [.parameter("page")])
      func listUsers(page: Int) async throws -> [User]
      """
    } expansion: {
      """
      func listUsers(page: Int) async throws -> [User]

      func listUsers(page: Int) async throws -> [User] {
        let path = "/users"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        var request = HTTPRequest(
          method: .get,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        request.addQueryParameter(name: "page", value: page)
        let response = try await client.execute(request)
        guard let responseBody = response.body else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
          )
        }
        return try JSONDecoder().decode([User].self, from: responseBody.rawValue)
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
      @GET(.path("/users"))
      func getUsers() -> [User]
      """
    } diagnostics: {
      """
      @GET(.path("/users"))
      ┬────────────────────
      ╰─ 🛑 Function 'getUsers' must be marked 'async'
      func getUsers() -> [User]
      """
    }
  }

  func testGETValidatesPathParameters() {
    assertMacro {
      """
      @GET(.path("/users/{userId}"))
      func getUser(id: String) async throws -> User
      """
    } diagnostics: {
      """
      @GET(.path("/users/{userId}"))
      ┬─────────────────────────────
      ╰─ 🛑 Path parameter mismatch in '/users/{userId}': function has parameters [id], but path requires [userId]
      func getUser(id: String) async throws -> User
      """
    }
  }
}
// swiftlint:enable line_length
