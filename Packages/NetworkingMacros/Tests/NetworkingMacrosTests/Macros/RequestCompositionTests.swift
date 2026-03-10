import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for request composition patterns.
///
/// Tests validate that macros generate correct HTTPRequest construction
/// with various compositions of path, query, headers, and body parameters.
final class RequestCompositionTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(macros: [GETMacro.self, POSTMacro.self, PUTMacro.self]) {
      super.invokeTest()
    }
  }

  // MARK: - Path Composition

  func testStaticPathComposition() {
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
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode([User].self, from response.data)
      }
      """
    }
  }

  func testSinglePathParameter() {
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
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode(User.self, from response.data)
      }
      """#
    }
  }

  func testMultiplePathParameters() {
    assertMacro {
      """
      @GET(.path("/users/{userId}/posts/{postId}"))
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

  func testNestedPathComposition() {
    assertMacro {
      """
      @GET(.path("/orgs/{orgId}/teams/{teamId}/projects/{projectId}"))
      func getProject(orgId: String, teamId: String, projectId: String) async throws -> Project
      """
    } expansion: {
      #"""
      func getProject(orgId: String, teamId: String, projectId: String) async throws -> Project

      func getProject(orgId: String teamId: String projectId: String) async throws -> Project {
          let path = "/orgs/\(orgId)/teams/\(teamId)/projects/\(projectId)"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode(Project.self, from response.data)
      }
      """#
    }
  }

  // MARK: - Body Composition

  func testSimpleBodyComposition() {
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

  func testBodyWithPathParameters() {
    assertMacro {
      """
      @PUT(.path("/users/{id}"))
      @Body(.parameter("user"))
      func updateUser(id: String, user: UpdateUserRequest) async throws -> User
      """
    } expansion: {
      #"""
      @Body(.parameter("user"))
      func updateUser(id: String, user: UpdateUserRequest) async throws -> User

      func updateUser(id: String user: UpdateUserRequest) async throws -> User {
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

}
