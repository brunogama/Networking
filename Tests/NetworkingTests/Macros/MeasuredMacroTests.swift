import MacroTesting
import SwiftSyntaxMacros
import Testing
import XCTest

@testable import Networking

#if canImport(NetworkingMacros)
  import NetworkingMacros
#endif

@Suite("Measured Macro Tests")
struct MeasuredMacroTests {

  @Test("@Measured generates timing wrapper")
  func measuredGeneratesWrapper() {
    #if canImport(NetworkingMacros)
      assertMacro(["Measured": MeasuredMacro.self]) {
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
          let duration = Date().timeIntervalSince(startTime)
          Metrics.shared.record(duration: duration, operation: "fetchUsers")
        }
        return try await fetchUsers()
      }
      """
      }
    #endif
  }

  @Test("@Measured with custom metric name")
  func measuredWithCustomName() {
    #if canImport(NetworkingMacros)
      assertMacro(["Measured": MeasuredMacro.self]) {
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
          let duration = Date().timeIntervalSince(startTime)
          Metrics.shared.record(duration: duration, operation: "user_fetch")
        }
        return try await fetchUsers()
      }
      """
      }
    #endif
  }

  @Test("@Measured emits diagnostic on non-function")
  func measuredDiagnosticOnNonFunction() {
    #if canImport(NetworkingMacros)
      assertMacro(["Measured": MeasuredMacro.self]) {
      """
      @Measured
      struct NotAFunction {}
      """
      } diagnostics: {
      """
      @Measured
      ┬────────
      ╰─ error: @Measured can only be applied to functions
      struct NotAFunction {}
      """
      }
    #endif
  }
}
