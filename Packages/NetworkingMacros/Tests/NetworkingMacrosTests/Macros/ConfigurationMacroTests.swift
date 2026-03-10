import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for configuration macros (@Timeout, @DefaultHeaders).
///
/// Tests validate proper validation and configuration handling for protocol-level
/// timeout and header defaults.
final class ConfigurationMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(macros: [TimeoutMacro.self, DefaultHeadersMacro.self]) {
      super.invokeTest()
    }
  }

  // MARK: - Timeout Macro Tests

  func testTimeoutBasicExpansion() {
    assertMacro {
      """
      @Timeout(.seconds(30.0))
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

  func testTimeoutOnProtocol() {
    assertMacro {
      """
      @Timeout(.seconds(60.0))
      protocol PostAPI {
        func getPosts() async throws -> [Post]
      }
      """
    } expansion: {
      """
      protocol PostAPI {
        func getPosts() async throws -> [Post]
      }
      """
    }
  }

  func testTimeoutRequiresProtocol() {
    assertMacro {
      """
      @Timeout(.seconds(30.0))
      struct UserService {
        func getUsers() async throws -> [User]
      }
      """
    } diagnostics: {
      """
      @Timeout(.seconds(30.0))
      ┬───────────────────────
      ╰─ 🛑 @Timeout can only be applied to protocols
      struct UserService {
        func getUsers() async throws -> [User]
      }
      """
    }
  }

  // MARK: - DefaultHeaders Macro Tests

  func testDefaultHeadersBasicExpansion() {
    assertMacro {
      """
      @DefaultHeaders([.named("Accept"): .literal("application/json")])
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

  func testDefaultHeadersMultiple() {
    assertMacro {
      """
      @DefaultHeaders([.named("Accept"): .literal("application/json"), .named("X-API-Version"): .literal("v1")])
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

  func testDefaultHeadersOnProtocol() {
    assertMacro {
      """
      @DefaultHeaders([.named("Authorization"): .literal("Bearer token")])
      protocol SecureAPI {
        func getData() async throws -> Data
      }
      """
    } expansion: {
      """
      protocol SecureAPI {
        func getData() async throws -> Data
      }
      """
    }
  }

  func testDefaultHeadersRequiresProtocol() {
    assertMacro {
      """
      @DefaultHeaders([.named("Accept"): .literal("application/json")])
      struct UserService {
        func getUsers() async throws -> [User]
      }
      """
    } diagnostics: {
      """
      @DefaultHeaders([.named("Accept"): .literal("application/json")])
      ┬────────────────────────────────────────────────────────────────
      ╰─ 🛑 @DefaultHeaders can only be applied to protocols
      struct UserService {
        func getUsers() async throws -> [User]
      }
      """
    }
  }

  // MARK: - Edge Cases

  func testTimeoutWithInteger() {
    assertMacro {
      """
      @Timeout(.seconds(45))
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

  func testDefaultHeadersEmptyDictionary() {
    assertMacro {
      """
      @DefaultHeaders([])
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    } diagnostics: {
      """
      @DefaultHeaders([])
      ┬──────────────────
      ╰─ 🛑 @DefaultHeaders requires a non-empty headers dictionary
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    }
  }
}
