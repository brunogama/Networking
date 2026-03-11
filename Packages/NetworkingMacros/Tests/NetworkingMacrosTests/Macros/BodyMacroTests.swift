import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for @Body using MacroTesting framework.
///
/// Tests validate that BodyMacro is a marker macro (returns empty peer code)
/// and correctly validates parameter names and function application.
final class BodyMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(macros: [BodyMacro.self]) {
      super.invokeTest()
    }
  }

  // MARK: - Basic Expansion Tests (marker macro returns empty)

  func testBodyMacroBasicUsage() {
    assertMacro {
      """
      @Body(.parameter("user"))
      func createUser(user: User) async throws -> User
      """
    } expansion: {
      """
      func createUser(user: User) async throws -> User
      """
    }
  }

  func testBodyMacroWithMultipleParameters() {
    assertMacro {
      """
      @Body(.parameter("data"))
      func updateUser(id: String, data: UserData) async throws -> User
      """
    } expansion: {
      """
      func updateUser(id: String, data: UserData) async throws -> User
      """
    }
  }

  func testBodyMacroWithInternalParameterName() {
    assertMacro {
      """
      @Body(.parameter("requestBody"))
      func createPost(for userId: String, requestBody: PostData) async throws -> Post
      """
    } expansion: {
      """
      func createPost(for userId: String, requestBody: PostData) async throws -> Post
      """
    }
  }

  // MARK: - Diagnostic Tests

  func testBodyMacroParameterNotFound() {
    assertMacro {
      """
      @Body(.parameter("nonexistent"))
      func createUser(user: User) async throws -> User
      """
    } diagnostics: {
      """
      @Body(.parameter("nonexistent"))
      ┬───────────────────────────────
      ╰─ 🛑 Body parameter 'nonexistent' not found in function signature. Available: [user]
      func createUser(user: User) async throws -> User
      """
    }
  }

  func testBodyMacroWithoutArgument() {
    assertMacro {
      """
      @Body
      func createUser(user: User) async throws -> User
      """
    } diagnostics: {
      """
      @Body
      ┬────
      ╰─ 🛑 Invalid path template '@Body requires parameter name: @Body(.parameter("parameterName"))'
      func createUser(user: User) async throws -> User
      """
    }
  }

  func testBodyMacroOnNonFunction() {
    assertMacro {
      """
      @Body(.parameter("value"))
      struct User {
        let value: String
      }
      """
    } diagnostics: {
      """
      @Body(.parameter("value"))
      ┬─────────────────────────
      ╰─ 🛑 Invalid path template '@Body can only be applied to functions'
      struct User {
        let value: String
      }
      """
    }
  }

  func testBodyMacroMultipleOnSameFunction() {
    assertMacro {
      """
      @Body(.parameter("user"))
      @Body(.parameter("data"))
      func createUser(user: User, data: UserData) async throws -> User
      """
    } diagnostics: {
      """
      @Body(.parameter("user"))
      ┬────────────────────────
      ╰─ 🛑 Invalid path template 'Only one @Body macro allowed per function. Found 2.'
      @Body(.parameter("data"))
      ┬────────────────────────
      ╰─ 🛑 Invalid path template 'Only one @Body macro allowed per function. Found 2.'
      func createUser(user: User, data: UserData) async throws -> User
      """
    }
  }
}
