import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import NetworkingMacros

/// Integration tests verifying complete macro workflows with @API, HTTP methods, and configuration.
final class MacroIntegrationTests: XCTestCase {
  // MARK: - DELETE Integration Tests

  func testDELETEWithAPIIntegration() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
        @DELETE("/users/{id}")
        func deleteUser(id: String) async throws
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func deleteUser(id: String) async throws

          func deleteUser(id: String) async throws {
            let path = "/users/\\(id)"
            var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)
            let _ = try await client.execute(request)
          }

            public struct UserAPIImplementation: UserAPI, Sendable {
                private let client: NetworkClient
                private let baseURL: String = "https://api.example.com"
                public init(client: NetworkClient = .shared) {
                  self.client = client
                }
            }
        }
        """,
      macros: [
        "API": APIMacro.self,
        "DELETE": DELETEMacro.self,
      ]
    )
  }

  func testDELETEWithReturnTypeIntegration() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.example.com")
      protocol ResourceAPI {
        @DELETE("/resources/{id}")
        func deleteResource(id: String) async throws -> DeletionResponse
      }
      """,
      expandedSource: """
        protocol ResourceAPI {
          func deleteResource(id: String) async throws -> DeletionResponse

          func deleteResource(id: String) async throws -> DeletionResponse {
            let path = "/resources/\\(id)"
            var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)
            let response = try await client.execute(request)
            return try JSONDecoder().decode(DeletionResponse.self, from: response.data)
          }

            public struct ResourceAPIImplementation: ResourceAPI, Sendable {
                private let client: NetworkClient
                private let baseURL: String = "https://api.example.com"
                public init(client: NetworkClient = .shared) {
                  self.client = client
                }
            }
        }
        """,
      macros: [
        "API": APIMacro.self,
        "DELETE": DELETEMacro.self,
      ]
    )
  }

  // MARK: - Configuration Integration Tests

  func testFullConfigurationIntegration() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.example.com")
      @DefaultHeaders(["Authorization": "Bearer token", "Accept": "application/json"])
      @Timeout(60.0)
      protocol SecureAPI {
        @GET("/data")
        func getData() async throws -> Data
      }
      """,
      expandedSource: """
        protocol SecureAPI {
          func getData() async throws -> Data

          func getData() async throws -> Data {
            let path = "/data"
            var request = HTTPRequest(method: .GET, path: path, baseURL: baseURL)
            let response = try await client.execute(request)
            return try JSONDecoder().decode(Data.self, from: response.data)
          }

            public struct SecureAPIImplementation: SecureAPI, Sendable {
                private let client: NetworkClient
                private let baseURL: String = "https://api.example.com"
                private let defaultHeaders: [String: String] = ["Accept": "application/json", "Authorization": "Bearer token"]
                private let defaultTimeout: Double = 60.0
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
        "GET": GETMacro.self,
      ]
    )
  }

  func testMultipleHTTPMethodsWithConfiguration() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.example.com/v1")
      @DefaultHeaders(["API-Key": "secret"])
      protocol CRUDApi {
        @GET("/items/{id}")
        func getItem(id: String) async throws -> Item

        @POST("/items", body: "item")
        func createItem(item: Item) async throws -> Item

        @DELETE("/items/{id}")
        func deleteItem(id: String) async throws
      }
      """,
      expandedSource: """
        protocol CRUDApi {
          func getItem(id: String) async throws -> Item

          func getItem(id: String) async throws -> Item {
            let path = "/items/\\(id)"
            var request = HTTPRequest(method: .GET, path: path, baseURL: baseURL)
            let response = try await client.execute(request)
            return try JSONDecoder().decode(Item.self, from: response.data)
          }
          func createItem(item: Item) async throws -> Item

          func createItem(item: Item) async throws -> Item {
            let path = "/items"
            var request = HTTPRequest(method: .POST, path: path, baseURL: baseURL)
            request.setBody(try JSONEncoder().encode(item))
            request.addHeader(name: "Content-Type", value: "application/json")
            let response = try await client.execute(request)
            return try JSONDecoder().decode(Item.self, from: response.data)
          }
          func deleteItem(id: String) async throws

          func deleteItem(id: String) async throws {
            let path = "/items/\\(id)"
            var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)
            let _ = try await client.execute(request)
          }

            public struct CRUDApiImplementation: CRUDApi, Sendable {
                private let client: NetworkClient
                private let baseURL: String = "https://api.example.com/v1"
                private let defaultHeaders: [String: String] = ["API-Key": "secret"]
                public init(client: NetworkClient = .shared) {
                  self.client = client
                }
            }
        }
        """,
      macros: [
        "API": APIMacro.self,
        "DefaultHeaders": DefaultHeadersMacro.self,
        "GET": GETMacro.self,
        "POST": POSTMacro.self,
        "DELETE": DELETEMacro.self,
      ]
    )
  }

  func testDELETEWithQueryParametersIntegration() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.example.com")
      @DefaultHeaders(["User-Agent": "TestClient/1.0"])
      protocol AdminAPI {
        @DELETE("/users/{id}", queryParameters: ["force", "cascade"])
        func deleteUser(id: String, force: Bool, cascade: Bool) async throws -> DeletionResult
      }
      """,
      expandedSource: """
        protocol AdminAPI {
          func deleteUser(id: String, force: Bool, cascade: Bool) async throws -> DeletionResult

          func deleteUser(id: String, force: Bool, cascade: Bool) async throws -> DeletionResult {
            let path = "/users/\\(id)"
            var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)
            request.addQueryParameter(name: "force", value: \\(force))
            request.addQueryParameter(name: "cascade", value: \\(cascade))
            let response = try await client.execute(request)
            return try JSONDecoder().decode(DeletionResult.self, from: response.data)
          }

            public struct AdminAPIImplementation: AdminAPI, Sendable {
                private let client: NetworkClient
                private let baseURL: String = "https://api.example.com"
                private let defaultHeaders: [String: String] = ["User-Agent": "TestClient/1.0"]
                public init(client: NetworkClient = .shared) {
                  self.client = client
                }
            }
        }
        """,
      macros: [
        "API": APIMacro.self,
        "DefaultHeaders": DefaultHeadersMacro.self,
        "DELETE": DELETEMacro.self,
      ]
    )
  }

  // MARK: - Configuration Inheritance Tests

  func testConfigurationPropertiesGenerated() throws {
    // Test that @API with @DefaultHeaders and @Timeout generates all properties
    // Note: Dictionary ordering may vary
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.github.com")
      @DefaultHeaders(["User-Agent": "MyApp"])
      @Timeout(30.0)
      protocol GitHubAPI {
      }
      """,
      expandedSource: """
        protocol GitHubAPI {

            public struct GitHubAPIImplementation: GitHubAPI, Sendable {
                private let client: NetworkClient
                private let baseURL: String = "https://api.github.com"
                private let defaultHeaders: [String: String] = ["User-Agent": "MyApp"]
                private let defaultTimeout: Double = 30.0
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

  func testPartialConfiguration() throws {
    // Test that configuration properties are optional
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.example.com")
      @DefaultHeaders(["API-Key": "12345"])
      protocol PartialAPI {
      }
      """,
      expandedSource: """
        protocol PartialAPI {

            public struct PartialAPIImplementation: PartialAPI, Sendable {
                private let client: NetworkClient
                private let baseURL: String = "https://api.example.com"
                private let defaultHeaders: [String: String] = ["API-Key": "12345"]
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
}
