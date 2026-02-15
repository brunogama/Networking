import MacroTesting
import SwiftSyntax
import SwiftSyntaxMacros
import Testing
import XCTest

@testable import NetworkingMacros

@Suite("Query Macro Tests")
struct QueryMacroTests {

  @Test("@Query generates GraphQL request with single variable")
  func queryGeneratesRequestWithSingleVariable() {
    assertMacro(["Query": QueryMacro.self]) {
      #"""
      @Query("""
        query GetUser($id: ID!) {
          user(id: $id) { id name email }
        }
      """)
      func getUser(id: String) async throws -> User
      """#
    } expansion: {
      #"""
      func getUser(id: String) async throws -> User {
        let request = GraphQLRequest(
          query: """
            query GetUser($id: ID!) {
              user(id: $id) { id name email }
            }
          """,
          variables: ["id": .string(id)],
          operationName: "GetUser"
        )
        return try await graphQL.execute(request, as: User.self)
      }
      """#
    }
  }

  @Test("@Query generates GraphQL request with multiple variables")
  func queryGeneratesRequestWithMultipleVariables() {
    assertMacro(["Query": QueryMacro.self]) {
      #"""
      @Query("""
        query SearchUsers($name: String!, $limit: Int!) {
          users(name: $name, limit: $limit) { id name }
        }
      """)
      func searchUsers(name: String, limit: Int) async throws -> [User]
      """#
    } expansion: {
      #"""
      func searchUsers(name: String, limit: Int) async throws -> [User] {
        let request = GraphQLRequest(
          query: """
            query SearchUsers($name: String!, $limit: Int!) {
              users(name: $name, limit: $limit) { id name }
            }
          """,
          variables: ["name": .string(name), "limit": .int(limit)],
          operationName: "SearchUsers"
        )
        return try await graphQL.execute(request, as: [User].self)
      }
      """#
    }
  }

  @Test("@Query emits diagnostic on non-function")
  func queryDiagnosticOnNonFunction() {
    assertMacro(["Query": QueryMacro.self]) {
      #"""
      @Query("query Test { test }")
      struct NotAFunction {}
      """#
    } diagnostics: {
      #"""
      @Query("query Test { test }")
      ┬─────
      ╰─ error: @Query can only be applied to functions
      struct NotAFunction {}
      """#
    }
  }

  @Test("@Query emits diagnostic on missing query string")
  func queryDiagnosticOnMissingQuery() {
    assertMacro(["Query": QueryMacro.self]) {
      #"""
      @Query
      func getUser(id: String) async throws -> User
      """#
    } diagnostics: {
      #"""
      @Query
      ┬─────
      ╰─ error: @Query requires a query string argument
      func getUser(id: String) async throws -> User
      """#
    }
  }
}
