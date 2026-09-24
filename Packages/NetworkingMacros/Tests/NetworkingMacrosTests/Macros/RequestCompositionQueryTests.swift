// swiftlint:disable line_length
import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

extension RequestCompositionTests {
  // MARK: - Query Parameter Composition

  func testSingleQueryParameter() {
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

  func testMultipleQueryParameters() {
    assertMacro {
      """
      @GET(.path("/search"), queryParameters: [.parameter("q"), .parameter("limit"), .parameter("offset")])
      func search(q: String, limit: Int, offset: Int) async throws -> SearchResults
      """
    } expansion: {
      """
      func search(q: String, limit: Int, offset: Int) async throws -> SearchResults

      func search(q: String, limit: Int, offset: Int) async throws -> SearchResults {
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
        request.addQueryParameter(name: "limit", value: limit)
        request.addQueryParameter(name: "offset", value: offset)
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

  func testOptionalQueryParameter() {
    assertMacro {
      """
      @GET(.path("/users"), queryParameters: [.parameter("filter")])
      func listUsers(filter: String?) async throws -> [User]
      """
    } expansion: {
      """
      func listUsers(filter: String?) async throws -> [User]

      func listUsers(filter: String?) async throws -> [User] {
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
        if let filter {
          request.addQueryParameter(name: "filter", value: filter)
        }
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

  // MARK: - Combined Composition

  func testPathAndQueryComposition() {
    assertMacro {
      """
      @GET(.path("/users/{id}/posts"), queryParameters: [.parameter("status")])
      func getUserPosts(id: String, status: String) async throws -> [Post]
      """
    } expansion: {
      #"""
      func getUserPosts(id: String, status: String) async throws -> [Post]

      func getUserPosts(id: String, status: String) async throws -> [Post] {
        let path = "/users/\(id)/posts"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        var request = HTTPRequest(
          method: .get,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        request.addQueryParameter(name: "status", value: status)
        let response = try await client.execute(request)
        guard let responseBody = response.body else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
          )
        }
        return try JSONDecoder().decode([Post].self, from: responseBody.rawValue)
      }
      """#
    }
  }

  func testPathBodyAndQueryComposition() {
    assertMacro {
      """
      @POST(.path("/projects/{projectId}/tasks"), queryParameters: [.parameter("notify")])
      @Body(.parameter("task"))
      func createTask(projectId: String, task: TaskRequest, notify: Bool) async throws -> Task
      """
    } expansion: {
      #"""
      @Body(.parameter("task"))
      func createTask(projectId: String, task: TaskRequest, notify: Bool) async throws -> Task

      func createTask(projectId: String, task: TaskRequest, notify: Bool) async throws -> Task {
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
        request.addQueryParameter(name: "notify", value: notify)
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
