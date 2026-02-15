import MacroTesting
import SwiftSyntaxMacros
import Testing
import XCTest

@testable import Networking

// Import macro types via conditional compilation to avoid module load errors
#if canImport(NetworkingMacros)
  import NetworkingMacros
#endif

@Suite("Cacheable Macro Tests")
struct CacheableMacroTests {

  @Test("@Cacheable generates cache configuration extension")
  func cacheableGeneratesConfiguration() {
    #if canImport(NetworkingMacros)
      assertMacro(["Cacheable": CacheableMacro.self]) {
      """
      @Cacheable(duration: 300)
      protocol UserAPI {
        func getUser(id: String) async throws -> User
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUser(id: String) async throws -> User
      }

      extension UserAPI {
        static var cacheConfiguration: CacheConfiguration {
          CacheConfiguration(
            duration: .ttl(300),
            policy: .standard
          )
        }
      }
      """
      }
    #endif
  }

  @Test("@Cacheable with custom policy")
  func cacheableWithCustomPolicy() {
    #if canImport(NetworkingMacros)
      assertMacro(["Cacheable": CacheableMacro.self]) {
      """
      @Cacheable(duration: 600, policy: .aggressive)
      protocol DataAPI {}
      """
    } expansion: {
      """
      protocol DataAPI {}

      extension DataAPI {
        static var cacheConfiguration: CacheConfiguration {
          CacheConfiguration(
            duration: .ttl(600),
            policy: .aggressive
          )
        }
      }
      """
      }
    #endif
  }

  @Test("@Cacheable emits diagnostic on non-protocol")
  func cacheableDiagnosticOnNonProtocol() {
    #if canImport(NetworkingMacros)
      assertMacro(["Cacheable": CacheableMacro.self]) {
      """
      @Cacheable(duration: 300)
      struct NotAProtocol {}
      """
    } diagnostics: {
      """
      @Cacheable(duration: 300)
      ┬─────────
      ╰─ error: @Cacheable can only be applied to protocols
      struct NotAProtocol {}
      """
      }
    #endif
  }
}
