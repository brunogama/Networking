import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import NetworkingMacros

/// Tests for @GET macro expansion.
final class GETMacroTests: XCTestCase {
  // MARK: - Success Cases

  func testGETBasicExpansion() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @GET("/users")
      func getUsers() async throws -> [User]
      """,
      expandedSource: """
        func getUsers() async throws -> [User]

        func getUsers() async throws -> [User] {
          let path = "/users"
          var request = HTTPRequest(method: .GET, path: path, baseURL: baseURL)
          let response = try await client.execute(request)
          return try JSONDecoder().decode([User].self, from: response.data)
        }
        """,
      macros: ["GET": GETMacro.self]
    )
  }

  func testGETWithPathParameters() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @GET("/users/{id}")
      func getUser(id: String) async throws -> User
      """,
      expandedSource: """
        func getUser(id: String) async throws -> User

        func getUser(id: String) async throws -> User {
          let path = "/users/\\(id)"
          var request = HTTPRequest(method: .GET, path: path, baseURL: baseURL)
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      macros: ["GET": GETMacro.self]
    )
  }

  func testGETWithMultiplePathParameters() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @GET("/users/{userId}/posts/{postId}")
      func getPost(userId: String, postId: String) async throws -> Post
      """,
      expandedSource: """
        func getPost(userId: String, postId: String) async throws -> Post

        func getPost(userId: String, postId: String) async throws -> Post {
          let path = "/users/\\(userId)/posts/\\(postId)"
          var request = HTTPRequest(method: .GET, path: path, baseURL: baseURL)
          let response = try await client.execute(request)
          return try JSONDecoder().decode(Post.self, from: response.data)
        }
        """,
      macros: ["GET": GETMacro.self]
    )
  }

  func testGETWithQueryParameters() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @GET("/users", queryParameters: ["page", "limit"])
      func getUsers(page: Int, limit: Int) async throws -> [User]
      """,
      expandedSource: """
        func getUsers(page: Int, limit: Int) async throws -> [User]

        func getUsers(page: Int, limit: Int) async throws -> [User] {
          let path = "/users"
          var request = HTTPRequest(method: .GET, path: path, baseURL: baseURL)
          request.addQueryParameter(name: "page", value: \\(page))
          request.addQueryParameter(name: "limit", value: \\(limit))
          let response = try await client.execute(request)
          return try JSONDecoder().decode([User].self, from: response.data)
        }
        """,
      macros: ["GET": GETMacro.self]
    )
  }

  func testGETWithPathAndQueryParameters() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @GET("/users/{id}/posts", queryParameters: ["status"])
      func getUserPosts(id: String, status: String) async throws -> [Post]
      """,
      expandedSource: """
        func getUserPosts(id: String, status: String) async throws -> [Post]

        func getUserPosts(id: String, status: String) async throws -> [Post] {
          let path = "/users/\\(id)/posts"
          var request = HTTPRequest(method: .GET, path: path, baseURL: baseURL)
          request.addQueryParameter(name: "status", value: \\(status))
          let response = try await client.execute(request)
          return try JSONDecoder().decode([Post].self, from: response.data)
        }
        """,
      macros: ["GET": GETMacro.self]
    )
  }

  // MARK: - Error Cases

  func testGETRequiresAsyncThrows() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @GET("/users")
      func getUsers() -> [User]
      """,
      expandedSource: """
        func getUsers() -> [User]
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Function 'getUsers' must be marked 'async'",
          line: 1,
          column: 1
        )
      ],
      macros: ["GET": GETMacro.self]
    )
  }

  func testGETRequiresPath() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @GET
      func getUsers() async throws -> [User]
      """,
      expandedSource: """
        func getUsers() async throws -> [User]
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@GET requires a path argument",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["GET": GETMacro.self]
    )
  }

  func testGETRequiresExplicitReturnType() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @GET("/users")
      func getUsers() async throws
      """,
      expandedSource: """
        func getUsers() async throws
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@GET methods must have an explicit return type",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["GET": GETMacro.self]
    )
  }

  func testGETPathParameterMismatch() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @GET("/users/{id}")
      func getUser(name: String) async throws -> User
      """,
      expandedSource: """
        func getUser(name: String) async throws -> User
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Path parameter mismatch in '/users/{id}': \
            function has parameters [name], \
            but path requires [id]
            """,
          line: 1,
          column: 1
        )
      ],
      macros: ["GET": GETMacro.self]
    )
  }

  func testGETQueryParameterNotFound() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @GET("/users", queryParameters: ["page", "limit"])
      func getUsers(page: Int) async throws -> [User]
      """,
      expandedSource: """
        func getUsers(page: Int) async throws -> [User]
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Query parameter 'limit' not found in function signature. \
            Available: [page]
            """,
          line: 1,
          column: 1
        )
      ],
      macros: ["GET": GETMacro.self]
    )
  }

  func testGETWithCustomHeaders() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @GET("/users", headers: ["X-Custom-Header": "CustomValue", "Authorization": "Bearer token"])
      func getUsers() async throws -> [User]
      """,
      expandedSource: """
        func getUsers() async throws -> [User]

        func getUsers() async throws -> [User] {
          let path = "/users"
          var request = HTTPRequest(method: .GET, path: path, baseURL: baseURL)
          request.addHeader(name: "Authorization", value: "Bearer token")
          request.addHeader(name: "X-Custom-Header", value: "CustomValue")
          let response = try await client.execute(request)
          return try JSONDecoder().decode([User].self, from: response.data)
        }
        """,
      macros: ["GET": GETMacro.self]
    )
  }
}
