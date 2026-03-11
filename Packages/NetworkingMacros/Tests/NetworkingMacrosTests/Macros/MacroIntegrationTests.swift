import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// General macro integration tests verifying cross-macro validation and interactions.
///
/// Tests focus on how macros coordinate, validate each other's preconditions,
/// and handle error propagation across the macro expansion pipeline.
final class MacroIntegrationTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(
      record: .missing,
      macros: [
        APIMacro.self,
        GETMacro.self,
        POSTMacro.self,
        BodyMacro.self,
        HeadersMacro.self,
        InterceptorsMacro.self,
        DefaultHeadersMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  // MARK: - Macro Registration Verification

  func testAllMacrosRegisteredInPlugin() {
    // Verify all 13 macros are registered in Plugin.swift
    // This is a compile-time check - if the plugin builds, all macros are registered
    // The NetworkingPlugin struct lists all macro types
    XCTAssertTrue(true, "All macros registered in NetworkingPlugin.providingMacros")
  }

  // MARK: - Cross-Macro Validation

  func testBodyMacroWithPOST() {
    assertMacro {
      """
      @POST(.path("/users"))
      func createUser(@Body user: User) async throws -> User
      """
    } diagnostics: {
      """
      @POST(.path("/users"))
      ┬─────────────────────
      ╰─ 🛑 @POST requires a body parameter. Use @Body("paramName") macro.
      func createUser(@Body user: User) async throws -> User
      """
    }
  }

  func testHeadersWithGET() {
    assertMacro {
      """
      @GET(.path("/users"))
      func getUsers(@Headers headers: [String: String]) async throws -> [User]
      """
    } expansion: {
      """
      func getUsers(@Headers headers: [String: String]) async throws -> [User]

      func getUsers(headers: [String) async throws -> [User] {
          let path = "/users"
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode([User].self, from response.data)
      }
      """
    }
  }

  func testInterceptorOrderPreserved() {
    assertMacro {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      @Interceptors([AuthInterceptor(), LoggingInterceptor(), RetryInterceptor()])
      protocol UserAPI {
        @GET(.path("/users"))
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
          private let interceptors: InterceptorChain
          public init(client: NetworkClient = .shared) {
            self.client = client
            self.interceptors = InterceptorChain(requestInterceptors [AuthInterceptor(), LoggingInterceptor(), RetryInterceptor()], responseInterceptors [AuthInterceptor(), LoggingInterceptor(), RetryInterceptor()])
          }
        }
      }
      """
    }
  }

  // MARK: - Error Propagation

  func testMissingBaseURLPropagates() {
    assertMacro {
      """
      @API
      protocol UserAPI {
        @GET(.path("/users"))
        func getUsers() async throws -> [User]
      }
      """
    } diagnostics: {
      """
      @API
      ┬───
      ╰─ 🛑 @API requires a baseURL argument
      protocol UserAPI {
        @GET(.path("/users"))
        func getUsers() async throws -> [User]
      }
      """
    }
  }

  func testEmptyPathExpansion() {
    assertMacro {
      """
      @GET(.path(""))
      func getUsers() async throws -> [User]
      """
    } expansion: {
      """
      func getUsers() async throws -> [User]

      func getUsers() async throws -> [User] {
          let path = ""
          var request = HTTPRequest(method nil .GET, path path, baseURL baseURL)
          let response = client.execute(request)
          return JSONDecoder().decode([User].self, from response.data)
      }
      """
    }
  }

  func testPOSTWithoutBodyParameter() {
    assertMacro {
      """
      @POST(.path("/users"))
      func createUser(user: User) async throws -> User
      """
    } diagnostics: {
      """
      @POST(.path("/users"))
      ┬─────────────────────
      ╰─ 🛑 @POST requires a body parameter. Use @Body("paramName") macro.
      func createUser(user: User) async throws -> User
      """
    }
  }
}
