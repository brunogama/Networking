import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

/// Test utilities for macro expansion testing.
///
/// Provides helper functions for asserting macro expansion results,
/// verifying diagnostics, and creating test data.
enum MacroTestHelpers {
  // MARK: - Macro Expansion Assertions

  /// Asserts that a macro expands to the expected code.
  ///
  /// Example:
  /// ```swift
  /// try assertMacroExpansion(
  ///   """
  ///   @API(baseURL: "https://api.example.com")
  ///   protocol UserAPI {
  ///     @GET("/users/{id}")
  ///     func getUser(id: String) async throws -> User
  ///   }
  ///   """,
  ///   expandedSource: expectedOutput,
  ///   macros: ["API": APIMacro.self, "GET": GETMacro.self]
  /// )
  /// ```
  static func assertMacroExpansion(
    _ source: String,
    expandedSource expected: String,
    macros: [String: Macro.Type],
    file: StaticString = #file,
    line: UInt = #line
  ) throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      source,
      expandedSource: expected,
      macros: macros,
      testModuleName: "NetworkingTests",
      testFileName: "MacroTests.swift",
      file: file,
      line: line
    )
  }

  // MARK: - Diagnostic Assertions

  /// Asserts that a macro expansion produces specific diagnostics.
  ///
  /// Example:
  /// ```swift
  /// assertMacroDiagnostics(
  ///   """
  ///   @GET("/users/{userId}")
  ///   func getUser(id: String) async throws -> User
  ///   """,
  ///   diagnostics: [
  ///     DiagnosticSpec(message: "Path parameter 'userId' not found", line: 1, column: 1)
  ///   ]
  /// )
  /// ```
  static func assertMacroDiagnostics(
    _ source: String,
    diagnostics expected: [DiagnosticSpec],
    macros: [String: Macro.Type],
    file: StaticString = #file,
    line: UInt = #line
  ) {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      source,
      expandedSource: source,  // No expansion expected when errors occur
      diagnostics: expected,
      macros: macros,
      testModuleName: "NetworkingTests",
      testFileName: "MacroTests.swift",
      file: file,
      line: line
    )
  }

  // MARK: - Test Data Builders

  /// Creates a minimal protocol declaration for testing.
  static func makeProtocolDeclaration(
    name: String,
    baseURL: String,
    functions: [String]
  ) -> String {
    let functionsJoined = functions.joined(separator: "\n  ")
    return """
      @API(baseURL: "\(baseURL)")
      protocol \(name) {
        \(functionsJoined)
      }
      """
  }

  /// Creates a GET function declaration.
  static func makeGETFunction(
    name: String,
    path: String,
    parameters: [(name: String, type: String)],
    returnType: String
  ) -> String {
    let params = parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
    return """
      @GET("\(path)")
      func \(name)(\(params)) async throws -> \(returnType)
      """
  }

  /// Creates a POST function declaration with body.
  static func makePOSTFunction(
    name: String,
    path: String,
    parameters: [(name: String, type: String)],
    bodyParameter: String,
    returnType: String
  ) -> String {
    let params = parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
    return """
      @POST("\(path)", body: "\(bodyParameter)")
      func \(name)(\(params)) async throws -> \(returnType)
      """
  }

  /// Creates a DELETE function declaration.
  static func makeDELETEFunction(
    name: String,
    path: String,
    parameters: [(name: String, type: String)]
  ) -> String {
    let params = parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
    return """
      @DELETE("\(path)")
      func \(name)(\(params)) async throws
      """
  }

  // MARK: - Common Test Patterns

  /// Standard user model for testing.
  static let userModelDeclaration = """
    struct User: Codable {
      let id: String
      let name: String
      let email: String
    }
    """

  /// Standard API base URL for testing.
  static let testBaseURL = "https://api.example.com"

  /// Common path patterns for testing.
  enum TestPaths {
    static let userById = "/users/{id}"
    static let userList = "/users"
    static let postsByUser = "/users/{userId}/posts"
    static let postById = "/posts/{id}"
    static let search = "/search"
  }

  /// Common function signatures for testing.
  enum TestFunctions {
    static let getUserById = makeGETFunction(
      name: "getUser",
      path: TestPaths.userById,
      parameters: [("id", "String")],
      returnType: "User"
    )

    static let listUsers = makeGETFunction(
      name: "listUsers",
      path: TestPaths.userList,
      parameters: [],
      returnType: "[User]"
    )

    static let createUser = makePOSTFunction(
      name: "createUser",
      path: TestPaths.userList,
      parameters: [("user", "User")],
      bodyParameter: "user",
      returnType: "User"
    )

    static let deleteUser = makeDELETEFunction(
      name: "deleteUser",
      path: TestPaths.userById,
      parameters: [("id", "String")]
    )
  }

  // MARK: - Expected Expansion Patterns

  /// Generates expected struct implementation for a protocol.
  static func makeExpectedImplementation(
    protocolName: String,
    functions: [String]
  ) -> String {
    let functionsJoined = functions.joined(separator: "\n\n  ")
    return """
      struct \(protocolName)Implementation: \(protocolName), Sendable {
        private let client: NetworkClient

        init(client: NetworkClient = .shared) {
          self.client = client
        }

        \(functionsJoined)
      }
      """
  }

  /// Generates expected function implementation for GET request.
  static func makeExpectedGETImplementation(
    name: String,
    path: String,
    pathParameters: [String],
    queryParameters: [String],
    parameters: [(name: String, type: String)],
    returnType: String,
    baseURL: String
  ) -> String {
    let params = parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", ")

    var body = ""

    // Add query parameter handling
    if !queryParameters.isEmpty {
      body += "var queryItems: [String: String] = [:]\n"
      for param in queryParameters {
        body += """
            if let \(param) = \(param) {
              queryItems["\(param)"] = String(\(param))
            }

          """
      }
    }

    // Generate path with interpolation
    var pathCode = path
    for param in pathParameters {
      pathCode = pathCode.replacingOccurrences(of: "{\(param)}", with: "\\(\(param))")
    }

    // Build request
    body += """
      let request = HTTPRequest {
        GET("\(pathCode)")
        BaseURL("\(baseURL)")
      """

    if !queryParameters.isEmpty {
      body += """

          if !queryItems.isEmpty {
            QueryParams(queryItems)
          }
        """
    }

    body += "\n}"

    // Execute and decode
    body += "\nlet response = try await client.execute(request)"
    if returnType != "Void" {
      body += "\nreturn try response.decode(\(returnType).self)"
    }

    return """
      func \(name)(\(params)) async throws -> \(returnType) {
        \(body)
      }
      """
  }
}
