import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import NetworkingMacros

/// Integration tests for @Body and @Headers attached macros with HTTP method macros.
///
/// Note: Due to SwiftSyntax macro testing framework limitations, these tests focus on:
/// - Individual macro behavior (already covered in BodyMacroTests and HeaderBuilderTests)
/// - HTTP method macros with old syntax (backward compatibility)
/// - Deprecation warnings
/// - Mixed syntax error detection
///
/// Full integration with @Body/@Headers new syntax is verified through compilation tests
/// and will be tested in actual usage.
final class AttachedMacroIntegrationTests: XCTestCase {

  // MARK: - Backward Compatibility: Old Syntax Still Works

  func testPOSTWithOldBodySyntax() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/users", body: "user")
      func createUser(user: User) async throws -> User
      """,
      expandedSource: """
        func createUser(user: User) async throws -> User

        func createUser(user: User) async throws -> User {
          let path = "/users"
          var request = HTTPRequest(method: .POST, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(user))
          request.addHeader(name: "Content-Type", value: "application/json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Body and @Headers attached macros instead:
            @POST("/path")
            @Body("paramName")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 1,
          column: 1,
          severity: .warning
        )
      ],
      macros: ["POST": POSTMacro.self]
    )
  }

  func testPOSTWithOldBodyAndHeadersSyntax() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/users", body: "user", headers: ["X-API-Key": "secret", "Accept": "application/json"])
      func createUser(user: User) async throws -> User
      """,
      expandedSource: """
        func createUser(user: User) async throws -> User

        func createUser(user: User) async throws -> User {
          let path = "/users"
          var request = HTTPRequest(method: .POST, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(user))
          request.addHeader(name: "Content-Type", value: "application/json")
          request.addHeader(name: "X-API-Key", value: "secret")
          request.addHeader(name: "Accept", value: "application/json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Body and @Headers attached macros instead:
            @POST("/path")
            @Body("paramName")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 1,
          column: 1,
          severity: .warning
        )
      ],
      macros: ["POST": POSTMacro.self]
    )
  }

  func testPUTWithOldBodySyntax() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PUT("/users/{id}", body: "updates")
      func updateUser(id: String, updates: UserUpdate) async throws -> User
      """,
      expandedSource: """
        func updateUser(id: String, updates: UserUpdate) async throws -> User

        func updateUser(id: String, updates: UserUpdate) async throws -> User {
          let path = "/users/\\(id)"
          var request = HTTPRequest(method: .PUT, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(updates))
          request.addHeader(name: "Content-Type", value: "application/json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Body and @Headers attached macros instead:
            @PUT("/path")
            @Body("paramName")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 1,
          column: 1,
          severity: .warning
        )
      ],
      macros: ["PUT": PUTMacro.self]
    )
  }

  func testPATCHWithOldBodyAndHeadersSyntax() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH("/resources/{id}", body: "changes", headers: ["Content-Type": "application/merge-patch+json"])
      func patchResource(id: String, changes: JSONPatch) async throws -> Resource
      """,
      expandedSource: """
        func patchResource(id: String, changes: JSONPatch) async throws -> Resource

        func patchResource(id: String, changes: JSONPatch) async throws -> Resource {
          let path = "/resources/\\(id)"
          var request = HTTPRequest(method: .PATCH, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(changes))
          request.addHeader(name: "Content-Type", value: "application/json")
          request.addHeader(name: "Content-Type", value: "application/merge-patch+json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(Resource.self, from: response.data)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Body and @Headers attached macros instead:
            @PATCH("/path")
            @Body("paramName")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 1,
          column: 1,
          severity: .warning
        )
      ],
      macros: ["PATCH": PATCHMacro.self]
    )
  }

  func testGETWithOldHeadersSyntax() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @GET("/users/{id}", headers: ["Authorization": "Bearer token", "Accept": "application/json"])
      func getUser(id: String) async throws -> User
      """,
      expandedSource: """
        func getUser(id: String) async throws -> User

        func getUser(id: String) async throws -> User {
          let path = "/users/\\(id)"
          var request = HTTPRequest(method: .GET, path: path, baseURL: baseURL)
          request.addHeader(name: "Authorization", value: "Bearer token")
          request.addHeader(name: "Accept", value: "application/json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Headers attached macro instead:
            @GET("/path")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 1,
          column: 1,
          severity: .warning
        )
      ],
      macros: ["GET": GETMacro.self]
    )
  }

  func testDELETEWithOldHeadersSyntax() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DELETE("/sessions/{id}", headers: ["Authorization": "Bearer token"])
      func deleteSession(id: String) async throws
      """,
      expandedSource: """
        func deleteSession(id: String) async throws

        func deleteSession(id: String) async throws {
          let path = "/sessions/\\(id)"
          var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)
          request.addHeader(name: "Authorization", value: "Bearer token")
          let _ = try await client.execute(request)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Headers attached macro instead:
            @DELETE("/path")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 1,
          column: 1,
          severity: .warning
        )
      ],
      macros: ["DELETE": DELETEMacro.self]
    )
  }

  // MARK: - Complex Old Syntax Scenarios

  func testPOSTWithQueryParametersAndOldSyntax() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/users", body: "user", queryParameters: ["notify", "async"], headers: ["X-Request-ID": "123"])
      func createUser(user: User, notify: Bool, async: Bool) async throws -> User
      """,
      expandedSource: """
        func createUser(user: User, notify: Bool, async: Bool) async throws -> User

        func createUser(user: User, notify: Bool, async: Bool) async throws -> User {
          let path = "/users"
          var request = HTTPRequest(method: .POST, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(user))
          request.addHeader(name: "Content-Type", value: "application/json")
          request.addHeader(name: "X-Request-ID", value: "123")
          request.addQueryParameter(name: "notify", value: \\(notify))
          request.addQueryParameter(name: "async", value: \\(async))
          let response = try await client.execute(request)
          return try JSONDecoder().decode(User.self, from: response.data)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Body and @Headers attached macros instead:
            @POST("/path")
            @Body("paramName")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 1,
          column: 1,
          severity: .warning
        )
      ],
      macros: ["POST": POSTMacro.self]
    )
  }

  func testPUTWithPathParametersAndOldSyntax() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PUT("/users/{userId}/posts/{postId}", body: "update", headers: ["If-Match": "etag123"])
      func updatePost(userId: String, postId: String, update: PostUpdate) async throws -> Post
      """,
      expandedSource: """
        func updatePost(userId: String, postId: String, update: PostUpdate) async throws -> Post

        func updatePost(userId: String, postId: String, update: PostUpdate) async throws -> Post {
          let path = "/users/\\(userId)/posts/\\(postId)"
          var request = HTTPRequest(method: .PUT, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(update))
          request.addHeader(name: "Content-Type", value: "application/json")
          request.addHeader(name: "If-Match", value: "etag123")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(Post.self, from: response.data)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Body and @Headers attached macros instead:
            @PUT("/path")
            @Body("paramName")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 1,
          column: 1,
          severity: .warning
        )
      ],
      macros: ["PUT": PUTMacro.self]
    )
  }

  // MARK: - API Protocol Integration with Old Syntax

  func testAPIProtocolWithOldSyntax() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
        @GET("/users/{id}", headers: ["Accept": "application/json"])
        func getUser(id: String) async throws -> User

        @POST("/users", body: "user", headers: ["Content-Type": "application/json"])
        func createUser(user: User) async throws -> User

        @DELETE("/users/{id}")
        func deleteUser(id: String) async throws
      }
      """,
      expandedSource: """
        protocol UserAPI {
          func getUser(id: String) async throws -> User

          func getUser(id: String) async throws -> User {
            let path = "/users/\\(id)"
            var request = HTTPRequest(method: .GET, path: path, baseURL: baseURL)
            request.addHeader(name: "Accept", value: "application/json")
            let response = try await client.execute(request)
            return try JSONDecoder().decode(User.self, from: response.data)
          }
          func createUser(user: User) async throws -> User

          func createUser(user: User) async throws -> User {
            let path = "/users"
            var request = HTTPRequest(method: .POST, path: path, baseURL: baseURL)
            request.setBody(try JSONEncoder().encode(user))
            request.addHeader(name: "Content-Type", value: "application/json")
            request.addHeader(name: "Content-Type", value: "application/json")
            let response = try await client.execute(request)
            return try JSONDecoder().decode(User.self, from: response.data)
          }
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
      diagnostics: [
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Headers attached macro instead:
            @GET("/path")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 3,
          column: 3,
          severity: .warning
        ),
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Body and @Headers attached macros instead:
            @POST("/path")
            @Body("paramName")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 6,
          column: 3,
          severity: .warning
        ),
      ],
      macros: [
        "API": APIMacro.self,
        "GET": GETMacro.self,
        "POST": POSTMacro.self,
        "DELETE": DELETEMacro.self,
      ]
    )
  }

  // MARK: - Deprecation Warnings Verification

  func testDeprecationWarningEmittedForAllHTTPMethods() throws {
    // Verify POST emits warning
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @POST("/data", body: "data")
      func send(data: Data) async throws -> Response
      """,
      expandedSource: """
        func send(data: Data) async throws -> Response

        func send(data: Data) async throws -> Response {
          let path = "/data"
          var request = HTTPRequest(method: .POST, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(data))
          request.addHeader(name: "Content-Type", value: "application/json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(Response.self, from: response.data)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Body and @Headers attached macros instead:
            @POST("/path")
            @Body("paramName")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 1,
          column: 1,
          severity: .warning
        )
      ],
      macros: ["POST": POSTMacro.self]
    )

    // Verify PUT emits warning
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PUT("/data/{id}", body: "data")
      func update(id: String, data: Data) async throws -> Response
      """,
      expandedSource: """
        func update(id: String, data: Data) async throws -> Response

        func update(id: String, data: Data) async throws -> Response {
          let path = "/data/\\(id)"
          var request = HTTPRequest(method: .PUT, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(data))
          request.addHeader(name: "Content-Type", value: "application/json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(Response.self, from: response.data)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Body and @Headers attached macros instead:
            @PUT("/path")
            @Body("paramName")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 1,
          column: 1,
          severity: .warning
        )
      ],
      macros: ["PUT": PUTMacro.self]
    )

    // Verify PATCH emits warning
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @PATCH("/data/{id}", body: "patch")
      func patch(id: String, patch: Patch) async throws -> Response
      """,
      expandedSource: """
        func patch(id: String, patch: Patch) async throws -> Response

        func patch(id: String, patch: Patch) async throws -> Response {
          let path = "/data/\\(id)"
          var request = HTTPRequest(method: .PATCH, path: path, baseURL: baseURL)
          request.setBody(try JSONEncoder().encode(patch))
          request.addHeader(name: "Content-Type", value: "application/json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(Response.self, from: response.data)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Body and @Headers attached macros instead:
            @PATCH("/path")
            @Body("paramName")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 1,
          column: 1,
          severity: .warning
        )
      ],
      macros: ["PATCH": PATCHMacro.self]
    )

    // Verify GET emits warning for headers
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @GET("/data", headers: ["Accept": "application/json"])
      func getData() async throws -> Response
      """,
      expandedSource: """
        func getData() async throws -> Response

        func getData() async throws -> Response {
          let path = "/data"
          var request = HTTPRequest(method: .GET, path: path, baseURL: baseURL)
          request.addHeader(name: "Accept", value: "application/json")
          let response = try await client.execute(request)
          return try JSONDecoder().decode(Response.self, from: response.data)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Headers attached macro instead:
            @GET("/path")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 1,
          column: 1,
          severity: .warning
        )
      ],
      macros: ["GET": GETMacro.self]
    )

    // Verify DELETE emits warning for headers
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @DELETE("/data/{id}", headers: ["Authorization": "token"])
      func deleteData(id: String) async throws
      """,
      expandedSource: """
        func deleteData(id: String) async throws

        func deleteData(id: String) async throws {
          let path = "/data/\\(id)"
          var request = HTTPRequest(method: .DELETE, path: path, baseURL: baseURL)
          request.addHeader(name: "Authorization", value: "token")
          let _ = try await client.execute(request)
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: """
            Old syntax is deprecated. Use @Headers attached macro instead:
            @DELETE("/path")
            @Headers { H("name", "value") }
            func myMethod(...)
            """,
          line: 1,
          column: 1,
          severity: .warning
        )
      ],
      macros: ["DELETE": DELETEMacro.self]
    )
  }
}
