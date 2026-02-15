#if MACRO_TESTS_ENABLED
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import NetworkingMacros

/// Tests for @Query macro expansion.
final class QueryMacroTests: XCTestCase {
  func testQueryGeneratesRequestWithSingleVariable() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Query(\"\"\"
        query GetUser($id: ID!) {
          user(id: $id) { id name email }
        }
      \"\"\")
      func getUser(id: String) async throws -> User
      """,
      expandedSource: """
        func getUser(id: String) async throws -> User {
          let request = GraphQLRequest(
            query: \"\"\"
        query GetUser($id: ID!) {
          user(id: $id) { id name email }
        }
        \"\"\",
            variables: ["id": .string(id)],
            operationName: "GetUser"
          )
          return try await graphQL.execute(request, as: User.self)
        }
        """,
      macros: ["Query": QueryMacro.self]
    )
  }

  func testQueryGeneratesRequestWithMultipleVariables() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Query(\"\"\"
        query SearchUsers($name: String!, $limit: Int!) {
          users(name: $name, limit: $limit) { id name }
        }
      \"\"\")
      func searchUsers(name: String, limit: Int) async throws -> [User]
      """,
      expandedSource: """
        func searchUsers(name: String, limit: Int) async throws -> [User] {
          let request = GraphQLRequest(
            query: \"\"\"
        query SearchUsers($name: String!, $limit: Int!) {
          users(name: $name, limit: $limit) { id name }
        }
        \"\"\",
            variables: ["name": .string(name), "limit": .int(limit)],
            operationName: "SearchUsers"
          )
          return try await graphQL.execute(request, as: [User].self)
        }
        """,
      macros: ["Query": QueryMacro.self]
    )
  }
}
#endif
