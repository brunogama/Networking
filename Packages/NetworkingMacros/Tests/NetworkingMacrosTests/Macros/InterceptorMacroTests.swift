import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for @Interceptors using MacroTesting framework.
///
/// Tests validate that InterceptorsMacro acts as a member macro that validates
/// syntax and provides interceptor configuration to APIMacro. The actual
/// interceptor chain initialization is handled by APIMacro when both macros
/// are present on a protocol.
final class InterceptorMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(macros: [InterceptorsMacro.self, APIMacro.self]) {
      super.invokeTest()
    }
  }

  // MARK: - Standalone Validation Tests

  func testInterceptorsStandaloneValidation() {
    assertMacro {
      """
      @Interceptors([LoggingInterceptor()])
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    }
  }

  func testInterceptorsWithMultipleItems() {
    assertMacro {
      """
      @Interceptors([AuthInterceptor(), LoggingInterceptor()])
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    }
  }

  // MARK: - Diagnostic Tests

  func testInterceptorsRequiresProtocol() {
    assertMacro {
      """
      @Interceptors([LoggingInterceptor()])
      struct UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    } diagnostics: {
      """
      @Interceptors([LoggingInterceptor()])
      ┬────────────────────────────────────
      ╰─ 🛑 @Interceptors can only be applied to protocols
      struct UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    }
  }

  func testInterceptorsRequiresArray() {
    assertMacro {
      """
      @Interceptors(LoggingInterceptor())
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    } diagnostics: {
      """
      @Interceptors(LoggingInterceptor())
      ┬──────────────────────────────────
      ╰─ 🛑 @Interceptors requires an array argument
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    }
  }

  func testInterceptorsEmptyArray() {
    assertMacro {
      """
      @Interceptors([])
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    } diagnostics: {
      """
      @Interceptors([])
      ┬────────────────
      ╰─ 🛑 @Interceptors requires a non-empty interceptor array
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    }
  }

  // NOTE: Combined @API + @Interceptors tests are in APIMacroTests
  // to verify the full integration of interceptor chain generation.
}
