// swiftlint:disable file_length type_body_length
import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for request operator patterns.
///
/// Tests validate that macros generate correct HTTPRequest structures,
/// response handling, error handling, and request modification patterns.
final class RequestOperatorsTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      macros: [
        GETMacro.self,
        POSTMacro.self,
        DELETEMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  // MARK: - Basic Request Structure

  func testGETRequestStructure() {
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

  func testPOSTRequestStructure() {
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

  func testDELETERequestStructure() {
    assertMacro {
      """
      @DELETE(.path("/users/{id}"))
      func deleteUser(id: String) async throws
      """
    } expansion: {
      #"""
      func deleteUser(id: String) async throws

      func deleteUser(id: String) async throws {
        let path = "/users/\(id)"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        let request = HTTPRequest(
          method: .delete,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        _ = try await client.execute(request)
        return
      }
      """#
    }
  }

  // MARK: - Response Handling Patterns

  func testDecodeResponsePattern() {
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

  func testVoidReturnPattern() {
    assertMacro {
      """
      @DELETE(.path("/users/{id}"))
      func deleteUser(id: String) async throws
      """
    } expansion: {
      #"""
      func deleteUser(id: String) async throws

      func deleteUser(id: String) async throws {
        let path = "/users/\(id)"
        guard let url = HTTPRequestURL(BaseURLText(rawValue: baseURL.rawValue + path)) else {
          throw URLError(.badURL)
        }
        let request = HTTPRequest(
          method: .delete,
          url: url,
          headers: defaultHeaders,
          timeout: defaultTimeout
        )
        _ = try await client.execute(request)
        return
      }
      """#
    }
  }

  func testArrayReturnPattern() {
    assertMacro {
      """
      @GET(.path("/users"))
      func listUsers() async throws -> [User]
      """
    } expansion: {
      """
      func listUsers() async throws -> [User]

      func listUsers() async throws -> [User] {
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

  // MARK: - Error Handling Patterns

  func testAsyncThrowsSignature() {
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

  func testRequiresAsyncThrows() {
    assertMacro {
      """
      @GET(.path("/users"))
      func getUsers() -> [User]
      """
    } diagnostics: {
      """
      @GET(.path("/users"))
      ┬────────────────────
      ╰─ 🛑 Function 'getUsers' must be marked 'async'
      func getUsers() -> [User]
      """
    }
  }

  // MARK: - Operator Chaining

  func testMultiplePathSegments() {
    assertMacro {
      """
      @GET(.path("/api/v1/users/{userId}/profile"))
      func getUserProfile(userId: String) async throws -> Profile
      """
    } expansion: {
      #"""
      func getUserProfile(userId: String) async throws -> Profile

      func getUserProfile(userId: String) async throws -> Profile {
        let path = "/api/v1/users/\(userId)/profile"
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
        return try JSONDecoder().decode(Profile.self, from: responseBody.rawValue)
      }
      """#
    }
  }

}
// swiftlint:enable file_length type_body_length
