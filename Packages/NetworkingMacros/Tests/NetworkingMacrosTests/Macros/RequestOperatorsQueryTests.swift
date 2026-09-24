// swiftlint:disable line_length
import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

extension RequestOperatorsTests {
  func testQueryParameterEncoding() {
    assertMacro {
      """
      @GET(.path("/search"), queryParameters: [.parameter("q"), .parameter("page"), .parameter("limit")])
      func search(q: String, page: Int, limit: Int) async throws -> SearchResults
      """
    } expansion: {
      """
      func search(q: String, page: Int, limit: Int) async throws -> SearchResults

      func search(q: String, page: Int, limit: Int) async throws -> SearchResults {
        let path = "/search"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        var request = HTTPRequest(
          method: .get,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        request.addQueryParameter(name: "q", value: q)
        request.addQueryParameter(name: "page", value: page)
        request.addQueryParameter(name: "limit", value: limit)
        let response = try await client.execute(request)
        guard let responseBody = response.body else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
          )
        }
        return try JSONDecoder().decode(SearchResults.self, from: responseBody.rawValue)
      }
      """
    }
  }

  // MARK: - Complex Composition

  func testComplexRequestComposition() {
    assertMacro {
      """
      @POST(.path("/projects/{projectId}/tasks"), queryParameters: [.parameter("priority")])
      @Body(.parameter("task"))
      func createTask(projectId: String, task: TaskRequest, priority: Int) async throws -> Task
      """
    } expansion: {
      #"""
      @Body(.parameter("task"))
      func createTask(projectId: String, task: TaskRequest, priority: Int) async throws -> Task

      func createTask(projectId: String, task: TaskRequest, priority: Int) async throws -> Task {
        let path = "/projects/\(projectId)/tasks"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        var request = HTTPRequest(
          method: .post,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        request.setBody(HTTPBody(try JSONEncoder().encode(task)))
        request.addHeader(name: "Content-Type", value: "application/json")
        request.addQueryParameter(name: "priority", value: priority)
        let response = try await client.execute(request)
        guard let responseBody = response.body else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
          )
        }
        return try JSONDecoder().decode(Task.self, from: responseBody.rawValue)
      }
      """#
    }
  }
}
// swiftlint:enable line_length
