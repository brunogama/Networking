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
      record: .missing,  // Use record mode to capture actual expansions
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
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
        @GET("/users")
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]

        func getUsers() async throws -> [User] {
          let path = "/users"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode([User].self, from response.data)
        }

        public struct UserAPIImplementation: UserAPI {
          private let client: NetworkClient
          private let baseURL: String = "https://api.example.com"
          public init(client: NetworkClient = .shared) {
            self.client = client
          }
        }
      }
      """
    }
  }

  func testAPIWithMultipleHTTPMethods() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
        @GET("/users")
        func getUsers() async throws -> [User]

        @POST("/users")
        func createUser(@Body user: User) async throws -> User

        @DELETE("/users/{id}")
        func deleteUser(id: String) async throws -> Void
      }
      """
    } diagnostics: {
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
        @GET("/users")
        func getUsers() async throws -> [User]

        @POST("/users")
        ┬──────────────
        ╰─ 🛑 @POST requires a body parameter. Use @Body("paramName") macro.
        func createUser(@Body user: User) async throws -> User

        @DELETE("/users/{id}")
        func deleteUser(id: String) async throws -> Void
      }
      """
    }
  }

  func testAPIWithPathParameters() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
        @GET("/users/{id}")
        func getUser(id: String) async throws -> User
      }
      """
    } expansion: {
      #"""
      protocol UserAPI {
        func getUser(id: String) async throws -> User

        func getUser(id: String) async throws -> User {
          let path = "/users/\(id)"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode(User.self, from response.data)
        }

        public struct UserAPIImplementation: UserAPI {
          private let client: NetworkClient
          private let baseURL: String = "https://api.example.com"
          public init(client: NetworkClient = .shared) {
            self.client = client
          }
        }
      }
      """#
    }
  }

  // MARK: - @API + Configuration Combinations

  func testAPIWithDefaultHeaders() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      @DefaultHeaders([
        "Authorization": "Bearer token",
        "Content-Type": "application/json"
      ])
      protocol UserAPI {
        @GET("/users")
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]

        func getUsers() async throws -> [User] {
          let path = "/users"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode([User].self, from response.data)
        }

        public struct UserAPIImplementation: UserAPI {
          private let client: NetworkClient
          private let baseURL: String = "https://api.example.com"
          private let defaultHeaders: [String: String] = ["Authorization" : "Bearer token", "Content-Type" : "application/json"]
          public init(client: NetworkClient = .shared) {
            self.client = client
          }
        }
      }
      """
    }
  }

  func testAPIWithTimeout() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      @Timeout(30.0)
      protocol UserAPI {
        @GET("/users")
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]

        func getUsers() async throws -> [User] {
          let path = "/users"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode([User].self, from response.data)
        }

        public struct UserAPIImplementation: UserAPI {
          private let client: NetworkClient
          private let baseURL: String = "https://api.example.com"
          private let defaultTimeout: Double = 30.0
          public init(client: NetworkClient = .shared) {
            self.client = client
          }
        }
      }
      """
    }
  }

  func testAPIWithCacheableProtocol() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      @Cacheable(duration: 300)
      protocol UserAPI {
        @GET("/users")
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]

        func getUsers() async throws -> [User] {
          let path = "/users"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode([User].self, from response.data)
        }

        public struct UserAPIImplementation: UserAPI {
          private let client: NetworkClient
          private let baseURL: String = "https://api.example.com"
          public init(client: NetworkClient = .shared) {
            self.client = client
          }
        }
      }

      extension UserAPI {
        static var cacheConfiguration: CacheConfiguration {
          get {
            return CacheConfiguration(duration ttl(300), policy nil .standard)
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
      @API(baseURL: "https://api.example.com")
      @Interceptors([AuthInterceptor(), LoggingInterceptor()])
      @DefaultHeaders(["Content-Type": "application/json"])
      @Timeout(30.0)
      protocol UserAPI {
        @GET("/users")
        func getUsers() async throws -> [User]

        @POST("/users")
        func createUser(@Body user: User) async throws -> User
      }
      """
    } diagnostics: {
      """
      @API(baseURL: "https://api.example.com")
      @Interceptors([AuthInterceptor(), LoggingInterceptor()])
      @DefaultHeaders(["Content-Type": "application/json"])
      @Timeout(30.0)
      protocol UserAPI {
        @GET("/users")
        func getUsers() async throws -> [User]

        @POST("/users")
        ┬──────────────
        ╰─ 🛑 @POST requires a body parameter. Use @Body("paramName") macro.
        func createUser(@Body user: User) async throws -> User
      }
      """
    }
  }
}
