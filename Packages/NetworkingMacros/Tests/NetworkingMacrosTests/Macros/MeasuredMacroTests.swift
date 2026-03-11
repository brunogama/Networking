import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for @Measured using MacroTesting framework.
///
/// Tests validate that MeasuredMacro generates correct timing instrumentation
/// wrapper functions with proper metric collection.
final class MeasuredMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(macros: [MeasuredMacro.self]) {
      super.invokeTest()
    }
  }

  // MARK: - Basic Expansion Tests

  func testMeasuredBasicExpansion() {
    assertMacro {
      """
      @Measured
      func fetchUsers() async throws -> [User] {
        return try await api.getUsers()
      }
      """
    } expansion: {
      """
      func fetchUsers() async throws -> [User] {
        return try await api.getUsers()
      }

      func fetchUsers_measured() async throws -> [User] {
        let startTime = Date()
        defer {
          let duration = Duration.seconds(Date().timeIntervalSince(startTime))
          Metrics.shared.record(duration: duration, operation: "fetchUsers")
        }
        return try await fetchUsers()
      }
      """
    }
  }

  func testMeasuredWithLabel() {
    assertMacro {
      """
      @Measured(name: "user_fetch")
      func fetchUsers() async throws -> [User] {
        return try await api.getUsers()
      }
      """
    } expansion: {
      """
      func fetchUsers() async throws -> [User] {
        return try await api.getUsers()
      }

      func fetchUsers_measured() async throws -> [User] {
        let startTime = Date()
        defer {
          let duration = Duration.seconds(Date().timeIntervalSince(startTime))
          Metrics.shared.record(duration: duration, operation: "user_fetch")
        }
        return try await fetchUsers()
      }
      """
    }
  }

  func testMeasuredOnFunction() {
    assertMacro {
      """
      @Measured
      func processData(_ input: String) async throws -> Result {
        return try await process(input)
      }
      """
    } expansion: {
      """
      func processData(_ input: String) async throws -> Result {
        return try await process(input)
      }

      func processData_measured(_ input: String) async throws -> Result {
        let startTime = Date()
        defer {
          let duration = Duration.seconds(Date().timeIntervalSince(startTime))
          Metrics.shared.record(duration: duration, operation: "processData")
        }
        return try await processData(input)
      }
      """
    }
  }

  // MARK: - Different Signatures

  func testMeasuredWithMultipleParameters() {
    assertMacro {
      """
      @Measured
      func updateUser(id: String, name: String) async throws -> User {
        return try await api.update(id, name)
      }
      """
    } expansion: {
      """
      func updateUser(id: String, name: String) async throws -> User {
        return try await api.update(id, name)
      }

      func updateUser_measured(id: String, name: String) async throws -> User {
        let startTime = Date()
        defer {
          let duration = Duration.seconds(Date().timeIntervalSince(startTime))
          Metrics.shared.record(duration: duration, operation: "updateUser")
        }
        return try await updateUser(id: id, name: name)
      }
      """
    }
  }

  func testMeasuredWithVoidReturn() {
    assertMacro {
      """
      @Measured
      func deleteUser(id: String) async throws {
        try await api.delete(id)
      }
      """
    } expansion: {
      """
      func deleteUser(id: String) async throws {
        try await api.delete(id)
      }

      func deleteUser_measured(id: String) async throws {
        let startTime = Date()
        defer {
          let duration = Duration.seconds(Date().timeIntervalSince(startTime))
          Metrics.shared.record(duration: duration, operation: "deleteUser")
        }
        return try await deleteUser(id: id)
      }
      """
    }
  }

  func testMeasuredPreservesDefaultValues() {
    assertMacro {
      """
      @Measured
      func fetchUser(
        id: String,
        includePosts: Bool = false
      ) async throws -> User {
        return try await api.fetch(id: id, includePosts: includePosts)
      }
      """
    } expansion: {
      """
      func fetchUser(
        id: String,
        includePosts: Bool = false
      ) async throws -> User {
        return try await api.fetch(id: id, includePosts: includePosts)
      }

      func fetchUser_measured(
        id: String,
        includePosts: Bool = false
      ) async throws -> User {
        let startTime = Date()
        defer {
          let duration = Duration.seconds(Date().timeIntervalSince(startTime))
          Metrics.shared.record(duration: duration, operation: "fetchUser")
        }
        return try await fetchUser(id: id, includePosts: includePosts)
      }
      """
    }
  }

  func testMeasuredPreservesInoutParameters() {
    assertMacro {
      """
      @Measured
      func updateBuffer(_ buffer: inout [String], suffix: String = "!") async throws {
        buffer.append(suffix)
      }
      """
    } expansion: {
      """
      func updateBuffer(_ buffer: inout [String], suffix: String = "!") async throws {
        buffer.append(suffix)
      }

      func updateBuffer_measured(_ buffer: inout [String], suffix: String = "!") async throws {
        let startTime = Date()
        defer {
          let duration = Duration.seconds(Date().timeIntervalSince(startTime))
          Metrics.shared.record(duration: duration, operation: "updateBuffer")
        }
        return try await updateBuffer(&buffer, suffix: suffix)
      }
      """
    }
  }

  // MARK: - Diagnostic Tests

  func testMeasuredRequiresFunction() {
    assertMacro {
      """
      @Measured
      struct UserService {
        func getUsers() async throws -> [User]
      }
      """
    } diagnostics: {
      """
      @Measured
      ┬────────
      ╰─ 🛑 @Measured can only be applied to functions
      struct UserService {
        func getUsers() async throws -> [User]
      }
      """
    }
  }

  func testMeasuredOnProtocol() {
    assertMacro {
      """
      @Measured
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    } diagnostics: {
      """
      @Measured
      ┬────────
      ╰─ 🛑 @Measured can only be applied to functions
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    }
  }
}
