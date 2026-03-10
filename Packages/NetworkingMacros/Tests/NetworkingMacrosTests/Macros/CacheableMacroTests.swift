import MacroTesting
import XCTest
@testable import NetworkingMacrosPlugin

/// Macro expansion tests for @Cacheable using MacroTesting framework.
///
/// Tests validate that CacheableMacro generates correct cache configuration
/// properties with proper duration and policy handling.
final class CacheableMacroTests: XCTestCase {
  override func invokeTest() {
    withMacroTesting(macros: [CacheableMacro.self]) {
      super.invokeTest()
    }
  }

  // MARK: - Basic Expansion Tests

  func testCacheableBasicExpansion() {
    assertMacro {
      """
      @Cacheable
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }

      extension UserAPI {
        static var cacheConfiguration: CacheConfiguration {
          get {
            return CacheConfiguration(duration ttl(Duration.seconds(300)), policy nil .standard)
          }
        }
      }
      """
    }
  }

  func testCacheableWithDuration() {
    assertMacro {
      """
      @Cacheable(duration: .seconds(600))
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }

      extension UserAPI {
        static var cacheConfiguration: CacheConfiguration {
          get {
            return CacheConfiguration(duration ttl(Duration.seconds(600)), policy nil .standard)
          }
        }
      }
      """
    }
  }

  func testCacheableWithPolicy() {
    assertMacro {
      """
      @Cacheable(duration: .seconds(300), policy: .aggressive)
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }

      extension UserAPI {
        static var cacheConfiguration: CacheConfiguration {
          get {
            return CacheConfiguration(duration ttl(Duration.seconds(300)), policy nil .aggressive)
          }
        }
      }
      """
    }
  }

  func testCacheableWithCustomDuration() {
    assertMacro {
      """
      @Cacheable(duration: .seconds(1800), policy: .standard)
      protocol PostAPI {
        func getPosts() async throws -> [Post]
      }
      """
    } expansion: {
      """
      protocol PostAPI {
        func getPosts() async throws -> [Post]
      }

      extension PostAPI {
        static var cacheConfiguration: CacheConfiguration {
          get {
            return CacheConfiguration(duration ttl(Duration.seconds(1800)), policy nil .standard)
          }
        }
      }
      """
    }
  }

  // MARK: - Diagnostic Tests

  func testCacheableRequiresProtocol() {
    assertMacro {
      """
      @Cacheable
      struct UserService {
        func getUsers() async throws -> [User]
      }
      """
    } diagnostics: {
      """
      @Cacheable
      ┬─────────
      ╰─ 🛑 @Cacheable can only be applied to protocols
      struct UserService {
        func getUsers() async throws -> [User]
      }
      """
    }
  }

  func testCacheableOnClass() {
    assertMacro {
      """
      @Cacheable
      class UserManager {
        func getUsers() async throws -> [User] { [] }
      }
      """
    } diagnostics: {
      """
      @Cacheable
      ┬─────────
      ╰─ 🛑 @Cacheable can only be applied to protocols
      class UserManager {
        func getUsers() async throws -> [User] { [] }
      }
      """
    }
  }

  // MARK: - Edge Cases

  func testCacheableWithZeroDuration() {
    assertMacro {
      """
      @Cacheable(duration: .seconds(0))
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }

      extension UserAPI {
        static var cacheConfiguration: CacheConfiguration {
          get {
            return CacheConfiguration(duration ttl(Duration.seconds(0)), policy nil .standard)
          }
        }
      }
      """
    }
  }

  func testCacheableWithLargeDuration() {
    assertMacro {
      """
      @Cacheable(duration: .seconds(86400))
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }

      extension UserAPI {
        static var cacheConfiguration: CacheConfiguration {
          get {
            return CacheConfiguration(duration ttl(Duration.seconds(86400)), policy nil .standard)
          }
        }
      }
      """
    }
  }
}
