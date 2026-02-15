import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(NetworkingMacros)
import NetworkingMacros
#endif

/// Tests for @DefaultHeaders and @Timeout configuration macros.
final class ConfigurationMacroTests: XCTestCase {
  // MARK: - DefaultHeaders Tests

  func testDefaultHeadersBasicExpansion() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DefaultHeaders(["Accept": "application/json"])
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func getUsers() async throws -> [User]
        }
        """,
      macros: ["DefaultHeaders": DefaultHeadersMacro.self]
    )
  }

  func testDefaultHeadersMultipleHeaders() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DefaultHeaders([
        "Accept": "application/json",
        "User-Agent": "MyApp/1.0",
        "X-API-Version": "2.0"
      ])
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func getUsers() async throws -> [User]
        }
        """,
      macros: ["DefaultHeaders": DefaultHeadersMacro.self]
    )
  }

  func testDefaultHeadersRequiresDictionary() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DefaultHeaders
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func getUsers() async throws -> [User]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@DefaultHeaders requires a dictionary argument",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["DefaultHeaders": DefaultHeadersMacro.self]
    )
  }

  func testDefaultHeadersRequiresNonEmpty() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DefaultHeaders([:])
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func getUsers() async throws -> [User]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@DefaultHeaders requires a non-empty headers dictionary",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["DefaultHeaders": DefaultHeadersMacro.self]
    )
  }

  func testDefaultHeadersOnlyOnProtocol() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DefaultHeaders(["Accept": "application/json"])
      struct UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        struct UserAPI {
          func getUsers() async throws -> [User]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@DefaultHeaders can only be applied to protocols",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["DefaultHeaders": DefaultHeadersMacro.self]
    )
  }

  // MARK: - Timeout Tests

  func testTimeoutBasicExpansion() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Timeout(30.0)
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func getUsers() async throws -> [User]
        }
        """,
      macros: ["Timeout": TimeoutMacro.self]
    )
  }

  func testTimeoutIntegerValue() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Timeout(60)
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func getUsers() async throws -> [User]
        }
        """,
      macros: ["Timeout": TimeoutMacro.self]
    )
  }

  func testTimeoutRequiresValue() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Timeout
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func getUsers() async throws -> [User]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Timeout requires a timeout value in seconds",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["Timeout": TimeoutMacro.self]
    )
  }

  func testTimeoutRequiresNumeric() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Timeout("30")
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func getUsers() async throws -> [User]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Timeout requires a numeric literal (e.g., 30.0 or 30)",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["Timeout": TimeoutMacro.self]
    )
  }

  func testTimeoutRequiresPositive() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Timeout(0.0)
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func getUsers() async throws -> [User]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Timeout requires a positive timeout value",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["Timeout": TimeoutMacro.self]
    )
  }

  func testTimeoutOnlyOnProtocol() {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Timeout(30.0)
      struct UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        struct UserAPI {
          func getUsers() async throws -> [User]
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Timeout can only be applied to protocols",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: ["Timeout": TimeoutMacro.self]
    )
  }

  // MARK: - APIMacro Configuration Integration Tests

  func testAPIMacroWithDefaultHeaders() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.example.com")
      @DefaultHeaders(["Accept": "application/json", "User-Agent": "MyApp/1.0"])
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func getUsers() async throws -> [User]

            public struct UserAPIImplementation: UserAPI, Sendable {
                private let client: NetworkClient
                private let baseURL: String = "https://api.example.com"
                private let defaultHeaders: [String: String] = ["Accept": "application/json", "User-Agent": "MyApp/1.0"]
                public init(client: NetworkClient = .shared) {
                  self.client = client
                }
            }
        }
        """,
      macros: [
        "API": APIMacro.self,
        "DefaultHeaders": DefaultHeadersMacro.self,
      ]
    )
  }

  func testAPIMacroWithTimeout() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.example.com")
      @Timeout(30.0)
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func getUsers() async throws -> [User]

            public struct UserAPIImplementation: UserAPI, Sendable {
                private let client: NetworkClient
                private let baseURL: String = "https://api.example.com"
                private let defaultTimeout: Double = 30.0
                public init(client: NetworkClient = .shared) {
                  self.client = client
                }
            }
        }
        """,
      macros: [
        "API": APIMacro.self,
        "Timeout": TimeoutMacro.self,
      ]
    )
  }

  func testAPIMacroWithAllConfigurations() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.example.com")
      @DefaultHeaders(["Accept": "application/json"])
      @Timeout(45.0)
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func getUsers() async throws -> [User]

            public struct UserAPIImplementation: UserAPI, Sendable {
                private let client: NetworkClient
                private let baseURL: String = "https://api.example.com"
                private let defaultHeaders: [String: String] = ["Accept": "application/json"]
                private let defaultTimeout: Double = 45.0
                public init(client: NetworkClient = .shared) {
                  self.client = client
                }
            }
        }
        """,
      macros: [
        "API": APIMacro.self,
        "DefaultHeaders": DefaultHeadersMacro.self,
        "Timeout": TimeoutMacro.self,
      ]
    )
  }

  func testAPIMacroWithoutConfiguration() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
        func getUsers() async throws -> [User]
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func getUsers() async throws -> [User]

            public struct UserAPIImplementation: UserAPI, Sendable {
                private let client: NetworkClient
                private let baseURL: String = "https://api.example.com"
                public init(client: NetworkClient = .shared) {
                  self.client = client
                }
            }
        }
        """,
      macros: ["API": APIMacro.self]
    )
  }
}
