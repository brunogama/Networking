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

  func testSinglePathParameter() {
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

  func testMultiplePathParameters() {
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

  func testNestedPathComposition() {
    assertMacro {
      """
      @GET("/orgs/{orgId}/teams/{teamId}/projects/{projectId}")
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

  // MARK: - Query Parameter Composition

  func testSingleQueryParameter() {
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

  func testMultipleQueryParameters() {
    assertMacro {
      """
      @GET("/search", query: ["q", "limit", "offset"])
      func search(q: String, limit: Int, offset: Int) async throws -> SearchResults
      """
    } expansion: {
      """
      func search(q: String, limit: Int, offset: Int) async throws -> SearchResults

      func search(q: String limit: Int offset: Int) async throws -> SearchResults {
          let path = "/search"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode(SearchResults.self, from response.data)
      }
      """
    }
  }

  func testOptionalQueryParameter() {
    assertMacro {
      """
      @GET("/users", query: ["filter"])
      func listUsers(filter: String?) async throws -> [User]
      """
    } expansion: {
      """
      func listUsers(filter: String?) async throws -> [User]

      func listUsers(filter: String?) async throws -> [User] {
          let path = "/users"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode([User].self, from response.data)
      }
      """
    }
  }

  // MARK: - Body Composition

  func testSimpleBodyComposition() {
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

  func testBodyWithPathParameters() {
    assertMacro {
      """
      @PUT("/users/{id}")
      @Body("user")
      func updateUser(id: String, user: UpdateUserRequest) async throws -> User
      """
    } expansion: {
      #"""
      @Body("user")
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

  // MARK: - Combined Composition

  func testPathAndQueryComposition() {
    assertMacro {
      """
      @GET("/users/{id}/posts", query: ["status"])
      func getUserPosts(id: String, status: String) async throws -> [Post]
      """
    } expansion: {
      #"""
      func getUserPosts(id: String, status: String) async throws -> [Post]

      func getUserPosts(id: String status: String) async throws -> [Post] {
          let path = "/users/\(id)/posts"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode([Post].self, from response.data)
      }
      """#
    }
  }

  func testPathBodyAndQueryComposition() {
    assertMacro {
      """
      @POST("/projects/{projectId}/tasks", query: ["notify"])
      @Body("task")
      func createTask(projectId: String, task: TaskRequest, notify: Bool) async throws -> Task
      """
    } expansion: {
      #"""
      @Body("task")
      func createTask(projectId: String, task: TaskRequest, notify: Bool) async throws -> Task

      func createTask(projectId: String task: TaskRequest notify: Bool) async throws -> Task {
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
