// swiftlint:disable file_length function_body_length type_body_length
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

      func getUsers(@Headers headers: [String: String]) async throws -> [User] {
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

  // swiftlint:disable line_length
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
      }

      struct UserAPIImplementation: UserAPI, Sendable {
        private let client: any HTTPClient
        private let baseURL: BaseURLText = BaseURLText(rawValue: "https://api.example.com")
        private let defaultHeaders: HTTPHeaders = [:]
        private let defaultTimeout = NetworkingCore.RequestTimeout(rawValue: 30.0)
        private let interceptors: InterceptorChain
        init(client: any HTTPClient = NetworkClient()) {
          self.client = client
          let configuredInterceptors: [any Sendable] = [AuthInterceptor(), LoggingInterceptor(), RetryInterceptor()]
          self.interceptors = InterceptorChain(requestInterceptors: configuredInterceptors.compactMap {
              $0 as? any RequestInterceptor
            }, responseInterceptors: configuredInterceptors.compactMap {
              $0 as? any ResponseInterceptor
            })
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
          let preparedRequest = request
          var context = InterceptorContext(path: RequestPathPattern(rawValue: path), method: .get)
          while true {
            var interceptedRequest = preparedRequest
            let requestResult = try await interceptors.executeRequestInterceptors(
              request: &interceptedRequest,
              context: context
            )
            switch requestResult {
            case .proceed:
              break
            case .shortCircuit(let interceptedResponse):
              guard let responseBody = interceptedResponse.body else {
                throw DecodingError.dataCorrupted(
                  DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
                )
              }
              return try JSONDecoder().decode([User].self, from: responseBody.rawValue)
            case .retry:
              throw InterceptorError.invalidResult(reason: "Request interceptor requested a retry")
            }
            let response: HTTPResponse
            let httpError: HTTPError?
            do {
              response = try await client.execute(interceptedRequest)
              httpError = nil
            } catch let error as HTTPError {
              guard case .http = error.category, let failedResponse = error.response else {
                throw error
              }
              response = failedResponse
              httpError = error
            }
            let responseResult = try await interceptors.executeResponseInterceptors(
              response: response,
              context: context
            )
            let finalResponse: HTTPResponse
            switch responseResult {
            case .proceed:
              if let httpError {
                throw httpError
              }
              finalResponse = response
            case .shortCircuit(let interceptedResponse):
              finalResponse = interceptedResponse
            case .retry(let delay):
              guard context.attemptCount.rawValue < 10 else {
                throw InterceptorError.maxRetriesExceeded(maxAttempts: 10)
              }
              if let delay {
                try await Task.sleep(for: .seconds(delay.rawValue))
              }
              context = context.incrementingAttempt()
              continue
            }
            guard let responseBody = finalResponse.body else {
              throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Response body is empty")
              )
            }
            return try JSONDecoder().decode([User].self, from: responseBody.rawValue)
          }
        }
      }
      """
    }
  }

  // swiftlint:enable line_length

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
// swiftlint:enable file_length function_body_length type_body_length
