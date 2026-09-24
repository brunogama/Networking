// swiftlint:disable file_length line_length
import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for @POST using MacroTesting framework.
///
/// Tests validate that POSTMacro generates correct HTTP method implementations
/// with proper body handling, path parameters, and query parameters.
final class POSTMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(macros: [POSTMacro.self]) {
      super.invokeTest()
    }
  }

  // MARK: - Basic Expansion Tests

  func testBasicPOSTExpansion() {
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
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        var request = HTTPRequest(
          method: .post,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        request.setBody(HTTPBody(try JSONEncoder().encode(user)))
        request.addHeader(name: "Content-Type", value: "application/json")
        let response = try await client.execute(request)
        guard let responseBody = response.body else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
          )
        }
        return try JSONDecoder().decode(User.self, from: responseBody.rawValue)
      }
      """
    }
  }

  func testPOSTWithPathParameter() {
    assertMacro {
      """
      @POST(.path("/users/{id}/profile"))
      @Body(.parameter("profile"))
      func updateProfile(id: String, profile: Profile) async throws -> Profile
      """
    } expansion: {
      #"""
      @Body(.parameter("profile"))
      func updateProfile(id: String, profile: Profile) async throws -> Profile

      func updateProfile(id: String, profile: Profile) async throws -> Profile {
        let path = "/users/\(id)/profile"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        var request = HTTPRequest(
          method: .post,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        request.setBody(HTTPBody(try JSONEncoder().encode(profile)))
        request.addHeader(name: "Content-Type", value: "application/json")
        let response = try await client.execute(request)
        guard let responseBody = response.body else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
          )
        }
        return try JSONDecoder().decode(Profile.self, from: responseBody.rawValue)
      }
      """#
    }
  }

  func testPOSTWithQueryParameter() {
    assertMacro {
      """
      @POST(.path("/users"), queryParameters: [.parameter("notify")])
      @Body(.parameter("user"))
      func createUser(user: CreateUserRequest, notify: Bool) async throws -> User
      """
    } expansion: {
      """
      @Body(.parameter("user"))
      func createUser(user: CreateUserRequest, notify: Bool) async throws -> User

      func createUser(user: CreateUserRequest, notify: Bool) async throws -> User {
        let path = "/users"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        var request = HTTPRequest(
          method: .post,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        request.setBody(HTTPBody(try JSONEncoder().encode(user)))
        request.addHeader(name: "Content-Type", value: "application/json")
        request.addQueryParameter(name: "notify", value: notify)
        let response = try await client.execute(request)
        guard let responseBody = response.body else {
          throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
          )
        }
        return try JSONDecoder().decode(User.self, from: responseBody.rawValue)
      }
      """
    }
  }

  func testPOSTWithAllParameters() {
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

  // MARK: - Diagnostic Tests

  func testPOSTRequiresBody() {
    assertMacro {
      """
      @POST(.path("/users"))
      func createUser(user: CreateUserRequest) async throws -> User
      """
    } diagnostics: {
      """
      @POST(.path("/users"))
      ┬─────────────────────
      ╰─ 🛑 @POST requires a body parameter. Use @Body("paramName") macro.
      func createUser(user: CreateUserRequest) async throws -> User
      """
    }
  }

  func testPOSTRequiresAsyncThrows() {
    assertMacro {
      """
      @POST(.path("/users"))
      @Body(.parameter("user"))
      func createUser(user: CreateUserRequest) -> User
      """
    } diagnostics: {
      """
      @POST(.path("/users"))
      ┬─────────────────────
      ╰─ 🛑 Function 'createUser' must be marked 'async'
      @Body(.parameter("user"))
      func createUser(user: CreateUserRequest) -> User
      """
    }
  }

  func testPOSTValidatesPathParameters() {
    assertMacro {
      """
      @POST(.path("/users/{userId}/posts"))
      @Body(.parameter("post"))
      func createPost(id: String, post: Post) async throws -> Post
      """
    } diagnostics: {
      """
      @POST(.path("/users/{userId}/posts"))
      ┬────────────────────────────────────
      ╰─ 🛑 Path parameter mismatch in '/users/{userId}/posts': function has parameters [id, post], but path requires [userId]
      @Body(.parameter("post"))
      func createPost(id: String, post: Post) async throws -> Post
      """
    }
  }
}
// swiftlint:enable file_length line_length
