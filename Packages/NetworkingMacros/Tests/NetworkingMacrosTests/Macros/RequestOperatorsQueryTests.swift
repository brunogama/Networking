import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

extension RequestOperatorsTests {
  func testQueryParameterEncoding() {
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

  // MARK: - Complex Composition

  func testComplexRequestComposition() {
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
}
