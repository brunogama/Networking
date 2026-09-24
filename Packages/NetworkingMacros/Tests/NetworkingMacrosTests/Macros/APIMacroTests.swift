import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for @API using MacroTesting framework.
///
/// Tests validate that APIMacro generates correct struct implementations
/// with proper client initialization, base URL handling, and protocol conformance.
final class APIMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(macros: [APIMacro.self]) {
      super.invokeTest()
    }
  }

  // MARK: - Basic Expansion Tests

  func testAPIBasicExpansion() {
    assertMacro {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      protocol UserAPI {
      }
      """
    } expansion: {
      """
      protocol UserAPI {
      }

      struct UserAPIImplementation: UserAPI, Sendable {
          private let client: any HTTPClient
          private let baseURL: BaseURLText = BaseURLText(rawValue: "https://api.example.com")
          private let defaultHeaders: HTTPHeaders = [:]
          private let defaultTimeout = NetworkingCore.RequestTimeout(rawValue: 30.0)
          init(client: any HTTPClient = NetworkClient()) {
            self.client = client
          }
      }
      """
    }
  }

  func testAPIWithComplexProtocolName() {
    assertMacro {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      protocol MyComplexAPIServiceProtocol {
      }
      """
    } expansion: {
      """
      protocol MyComplexAPIServiceProtocol {
      }

      struct MyComplexAPIServiceProtocolImplementation: MyComplexAPIServiceProtocol, Sendable {
          private let client: any HTTPClient
          private let baseURL: BaseURLText = BaseURLText(rawValue: "https://api.example.com")
          private let defaultHeaders: HTTPHeaders = [:]
          private let defaultTimeout = NetworkingCore.RequestTimeout(rawValue: 30.0)
          init(client: any HTTPClient = NetworkClient()) {
            self.client = client
          }
      }
      """
    }
  }

  // MARK: - Diagnostic Tests

  func testAPIRequiresProtocol() {
    assertMacro {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      struct UserAPI {
      }
      """
    } diagnostics: {
      """
      @API(baseURL: .absolute("https://api.example.com"))
      ┬──────────────────────────────────────────────────
      ╰─ 🛑 @API can only be applied to protocols
      struct UserAPI {
      }
      """
    }
  }

  func testAPIRequiresBaseURL() {
    assertMacro {
      """
      @API
      protocol UserAPI {
      }
      """
    } diagnostics: {
      """
      @API
      ┬───
      ╰─ 🛑 @API requires a baseURL argument
      protocol UserAPI {
      }
      """
    }
  }

  func testAPIEmptyBaseURL() {
    assertMacro {
      """
      @API(baseURL: .absolute(""))
      protocol UserAPI {
      }
      """
    } diagnostics: {
      """
      @API(baseURL: .absolute(""))
      ┬───────────────────────────
      ╰─ 🛑 Base URL cannot be empty
      protocol UserAPI {
      }
      """
    }
  }
}
