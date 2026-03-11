import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

extension RequestCompositionTests {
  // MARK: - Query Parameter Composition

  func testSingleQueryParameter() {
    assertMacro {
      """
      @GET(.path("/users"), query: [.parameter("page")])
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
      @GET(.path("/search"), query: [.parameter("q"), .parameter("limit"), .parameter("offset")])
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
      @GET(.path("/users"), query: [.parameter("filter")])
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

  // MARK: - Combined Composition

  func testPathAndQueryComposition() {
    assertMacro {
      """
      @GET(.path("/users/{id}/posts"), query: [.parameter("status")])
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
      @POST(.path("/projects/{projectId}/tasks"), query: [.parameter("notify")])
      @Body(.parameter("task"))
      func createTask(projectId: String, task: TaskRequest, notify: Bool) async throws -> Task
      """
    } expansion: {
      #"""
      @Body(.parameter("task"))
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
