// swiftlint:disable file_length function_body_length line_length type_body_length
import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Integration tests verifying multiple attached macros working together.
///
/// Tests validate that @API, HTTP methods, @Headers, @Interceptors, and configuration macros
/// coordinate correctly when combined in realistic API protocol definitions.
final class AttachedMacroIntegrationTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      macros: [
        APIMacro.self,
        GETMacro.self,
        POSTMacro.self,
        DELETEMacro.self,
        BodyMacro.self,
        DefaultHeadersMacro.self,
        TimeoutMacro.self,
        CacheableMacro.self,
        InterceptorsMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  // MARK: - @API + HTTP Method Combinations

  func testAPIWithSingleGET() {
    assertMacro {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      protocol UserAPI {
        @GET(.path("/users"))
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }

      struct UserAPIImplementation: UserAPI, Sendable {
        private let client: any HTTPClient
        private let baseURL: BaseURLText = BaseURLText(rawValue: "https://api.example.com")
        private let defaultHeaders: HTTPHeaders = [:]
        private let defaultTimeout = NetworkingCore.RequestTimeout(rawValue: 30.0)
        init(client: any HTTPClient = NetworkClient()) {
          self.client = client
        }
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
      }
      """
    }
  }

  func testAPIWithMultipleHTTPMethods() {
    assertMacro {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      protocol UserAPI {
        @GET(.path("/users"))
        func getUsers() async throws -> [User]

        @POST(.path("/users"))
        func createUser(@Body user: User) async throws -> User

        @DELETE(.path("/users/{id}"))
        func deleteUser(id: String) async throws -> Void
      }
      """
    } diagnostics: {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      protocol UserAPI {
        @GET(.path("/users"))
        func getUsers() async throws -> [User]

        @POST(.path("/users"))
        ┬─────────────────────
        ╰─ 🛑 @POST requires a body parameter. Use @Body("paramName") macro.
        func createUser(@Body user: User) async throws -> User

        @DELETE(.path("/users/{id}"))
        func deleteUser(id: String) async throws -> Void
      }
      """
    }
  }

  func testAPIWithPathParameters() {
    assertMacro {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      protocol UserAPI {
        @GET(.path("/users/{id}"))
        func getUser(id: String) async throws -> User
      }
      """
    } expansion: {
      #"""
      protocol UserAPI {
        func getUser(id: String) async throws -> User
      }

      struct UserAPIImplementation: UserAPI, Sendable {
        private let client: any HTTPClient
        private let baseURL: BaseURLText = BaseURLText(rawValue: "https://api.example.com")
        private let defaultHeaders: HTTPHeaders = [:]
        private let defaultTimeout = NetworkingCore.RequestTimeout(rawValue: 30.0)
        init(client: any HTTPClient = NetworkClient()) {
          self.client = client
        }
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
      }
      """#
    }
  }

  // MARK: - @API + Configuration Combinations

  func testAPIWithDefaultHeaders() {
    assertMacro {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      @DefaultHeaders([.named("Authorization"): .literal("Bearer token"), .named("Content-Type"): .literal("application/json")])
      protocol UserAPI {
        @GET(.path("/users"))
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }

      struct UserAPIImplementation: UserAPI, Sendable {
        private let client: any HTTPClient
        private let baseURL: BaseURLText = BaseURLText(rawValue: "https://api.example.com")
        private let defaultHeaders: HTTPHeaders = ["Authorization": "Bearer token", "Content-Type": "application/json"]
        private let defaultTimeout = NetworkingCore.RequestTimeout(rawValue: 30.0)
        init(client: any HTTPClient = NetworkClient()) {
          self.client = client
        }
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
      }
      """
    }
  }

  func testAPIWithTimeout() {
    assertMacro {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      @Timeout(.seconds(30.0))
      protocol UserAPI {
        @GET(.path("/users"))
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }

      struct UserAPIImplementation: UserAPI, Sendable {
        private let client: any HTTPClient
        private let baseURL: BaseURLText = BaseURLText(rawValue: "https://api.example.com")
        private let defaultHeaders: HTTPHeaders = [:]
        private let defaultTimeout = NetworkingCore.RequestTimeout(rawValue: 30.0)
        init(client: any HTTPClient = NetworkClient()) {
          self.client = client
        }
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
      }
      """
    }
  }

  func testAPIWithCacheableProtocol() {
    assertMacro {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      @Cacheable(duration: .seconds(300))
      protocol UserAPI {
        @GET(.path("/users"))
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }

      struct UserAPIImplementation: UserAPI, Sendable {
        private let client: any HTTPClient
        private let baseURL: BaseURLText = BaseURLText(rawValue: "https://api.example.com")
        private let defaultHeaders: HTTPHeaders = [:]
        private let defaultTimeout = NetworkingCore.RequestTimeout(rawValue: 30.0)
        init(client: any HTTPClient = NetworkClient()) {
          self.client = client
        }
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
      }

      extension UserAPI {
        static var cacheConfiguration: CacheConfiguration {
          get {
            return CacheConfiguration(duration: ttl(Duration.seconds(300)), policy: .standard)
          }
        }
      }
      """
    }
  }

  // MARK: - Full Stack Integration

  func testFullAPIWithAllFeatures() {
    assertMacro {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      @Interceptors([AuthInterceptor(), LoggingInterceptor()])
      @DefaultHeaders([.named("Content-Type"): .literal("application/json")])
      @Timeout(.seconds(30.0))
      protocol UserAPI {
        @GET(.path("/users"))
        func getUsers() async throws -> [User]

        @POST(.path("/users"))
        func createUser(@Body user: User) async throws -> User
      }
      """
    } diagnostics: {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      @Interceptors([AuthInterceptor(), LoggingInterceptor()])
      @DefaultHeaders([.named("Content-Type"): .literal("application/json")])
      @Timeout(.seconds(30.0))
      protocol UserAPI {
        @GET(.path("/users"))
        func getUsers() async throws -> [User]

        @POST(.path("/users"))
        ┬─────────────────────
        ╰─ 🛑 @POST requires a body parameter. Use @Body("paramName") macro.
        func createUser(@Body user: User) async throws -> User
      }
      """
    }
  }
}
// swiftlint:enable file_length function_body_length line_length type_body_length
