import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for @Headers using MacroTesting framework.
///
/// **NOTE**: @Headers uses result builder closure syntax that requires special
/// handling in MacroTesting. Full expansion tests are limited by the trailing
/// closure parsing in the macro system. These tests focus on verifiable diagnostic
/// cases and the marker macro behavior (returns empty).
///
/// For full integration testing, see APIMacroTests which tests @Headers in
/// combination with @API and HTTP method macros.
final class HeaderBuilderTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(macros: [HeadersMacro.self]) {
      super.invokeTest()
    }
  }

  // MARK: - Diagnostic Tests

  func testHeadersRequiresClosure() {
    assertMacro {
      """
      @Headers
      func getUser() async throws -> User
      """
    } diagnostics: {
      """
      @Headers
      ┬───────
      ╰─ 🛑 @Headers requires result builder closure: @Headers { H(.named("name"), .literal("value")) }
      func getUser() async throws -> User
      """
    }
  }

  func testHeadersOnNonFunction() {
    assertMacro {
      """
      @Headers
      struct User {
        let id: String
      }
      """
    } diagnostics: {
      """
      @Headers
      ┬───────
      ╰─ 🛑 @Headers can only be applied to functions
      struct User {
        let id: String
      }
      """
    }
  }

  // NOTE: Tests for closure syntax (@Headers { ... }) are deferred due to
  // MacroTesting framework limitations with result builder closures.
  // These are tested via integration tests in APIMacroTests instead.
}
