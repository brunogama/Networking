// swiftlint:disable file_length type_body_length
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

  func testMultiplePathParameters() {
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

  func testNestedPathComposition() {
    assertMacro {
      """
      @GET(.path("/orgs/{orgId}/teams/{teamId}/projects/{projectId}"))
      func getProject(orgId: String, teamId: String, projectId: String) async throws -> Project
      """
    } expansion: {
      #"""
      func getProject(orgId: String, teamId: String, projectId: String) async throws -> Project

      func getProject(orgId: String, teamId: String, projectId: String) async throws -> Project {
        let path = "/orgs/\(orgId)/teams/\(teamId)/projects/\(projectId)"
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
        return try JSONDecoder().decode(Project.self, from: responseBody.rawValue)
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

      func updateUser(id: String, user: UpdateUserRequest) async throws -> User {
        let path = "/users/\(id)"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        var request = HTTPRequest(
          method: .put,
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
      """#
    }
  }

}
// swiftlint:enable file_length type_body_length
