import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// End-to-end integration tests for realistic API patterns.
///
/// Tests validate that the macro system produces production-quality code
/// for complete, real-world API definitions with complex scenarios.
final class IntegrationTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      record: .missing,
      macros: [
        APIMacro.self,
        GETMacro.self,
        POSTMacro.self,
        PUTMacro.self,
        DELETEMacro.self,
        BodyMacro.self,
        HeadersMacro.self,
        DefaultHeadersMacro.self,
        TimeoutMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  // MARK: - Real-World API Patterns

  func testUserAPIPattern() {
    assertMacro {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      protocol UserAPI {
        @GET(.path("/users"))
        func listUsers() async throws -> [User]

        @GET(.path("/users/{id}"))
        func getUser(id: String) async throws -> User

        @POST(.path("/users"))
        func createUser(@Body user: User) async throws -> User

        @PUT(.path("/users/{id}"))
        func updateUser(id: String, @Body user: User) async throws -> User

        @DELETE(.path("/users/{id}"))
        func deleteUser(id: String) async throws -> Void
      }
      """
    } diagnostics: {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      protocol UserAPI {
        @GET(.path("/users"))
        func listUsers() async throws -> [User]

        @GET(.path("/users/{id}"))
        func getUser(id: String) async throws -> User

        @POST(.path("/users"))
        ┬─────────────────────
        ╰─ 🛑 @POST requires a body parameter. Use @Body("paramName") macro.
        func createUser(@Body user: User) async throws -> User

        @PUT(.path("/users/{id}"))
        ┬─────────────────────────
        ╰─ 🛑 @PUT requires a body parameter. Use @Body("paramName") macro.
        func updateUser(id: String, @Body user: User) async throws -> User

        @DELETE(.path("/users/{id}"))
        func deleteUser(id: String) async throws -> Void
      }
      """
    }
  }

  func testAuthenticatedAPIPattern() {
    assertMacro {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      @DefaultHeaders([.named("Authorization"): .literal("Bearer token")])
      protocol SecureAPI {
        @GET(.path("/profile"))
        func getProfile() async throws -> Profile

        @POST(.path("/logout"))
        func logout(@Body request: LogoutRequest) async throws -> Void
      }
      """
    } diagnostics: {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      @DefaultHeaders([.named("Authorization"): .literal("Bearer token")])
      protocol SecureAPI {
        @GET(.path("/profile"))
        func getProfile() async throws -> Profile

        @POST(.path("/logout"))
        ┬──────────────────────
        ╰─ 🛑 @POST requires a body parameter. Use @Body("paramName") macro.
        func logout(@Body request: LogoutRequest) async throws -> Void
      }
      """
    }
  }

  func testRESTfulResourcePattern() {
    assertMacro {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      @Timeout(.seconds(30.0))
      protocol PostAPI {
        @GET(.path("/posts"))
        func listPosts() async throws -> [Post]

        @GET(.path("/posts/{id}"))
        func getPost(id: String) async throws -> Post

        @POST(.path("/posts"))
        func createPost(@Body post: Post) async throws -> Post

        @PUT(.path("/posts/{id}"))
        func updatePost(id: String, @Body post: Post) async throws -> Post

        @DELETE(.path("/posts/{id}"))
        func deletePost(id: String) async throws -> Void
      }
      """
    } diagnostics: {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      @Timeout(.seconds(30.0))
      protocol PostAPI {
        @GET(.path("/posts"))
        func listPosts() async throws -> [Post]

        @GET(.path("/posts/{id}"))
        func getPost(id: String) async throws -> Post

        @POST(.path("/posts"))
        ┬─────────────────────
        ╰─ 🛑 @POST requires a body parameter. Use @Body("paramName") macro.
        func createPost(@Body post: Post) async throws -> Post

        @PUT(.path("/posts/{id}"))
        ┬─────────────────────────
        ╰─ 🛑 @PUT requires a body parameter. Use @Body("paramName") macro.
        func updatePost(id: String, @Body post: Post) async throws -> Post

        @DELETE(.path("/posts/{id}"))
        func deletePost(id: String) async throws -> Void
      }
      """
    }
  }

  // MARK: - Complex Scenarios

  func testNestedPathParameters() {
    assertMacro {
      """
      @GET(.path("/users/{userId}/posts/{postId}/comments/{commentId}"))
      func getComment(userId: String, postId: String, commentId: String) async throws -> Comment
      """
    } expansion: {
      #"""
      func getComment(userId: String, postId: String, commentId: String) async throws -> Comment

      func getComment(userId: String postId: String commentId: String) async throws -> Comment {
          let path = "/users/\(userId)/posts/\(postId)/comments/\(commentId)"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode(Comment.self, from response.data)
      }
      """#
    }
  }

  func testQueryParameterCombinations() {
    assertMacro {
      """
      @GET(.path("/search"), query: [.parameter("q"), .parameter("page"), .parameter("limit")])
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

  func testMixedBodyAndQueryParams() {
    assertMacro {
      """
      @POST(.path("/users/search"), query: [.parameter("includeDeleted")])
      func searchUsers(@Body criteria: SearchCriteria, includeDeleted: Bool) async throws -> [User]
      """
    } diagnostics: {
      """
      @POST(.path("/users/search"), query: [.parameter("includeDeleted")])
      ┬───────────────────────────────────────────────────────────────────
      ╰─ 🛑 @POST requires a body parameter. Use @Body("paramName") macro.
      func searchUsers(@Body criteria: SearchCriteria, includeDeleted: Bool) async throws -> [User]
      """
    }
  }
}
