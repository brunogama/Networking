#if MACRO_TESTS_ENABLED
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import NetworkingGraphQLMacros

/// Tests for @Mutation macro expansion.
final class MutationMacroTests: XCTestCase {
  func testMutationGeneratesRequest() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Mutation(\"\"\"
        mutation CreateUser($name: String!, $email: String!) {
          createUser(name: $name, email: $email) { id name }
        }
      \"\"\")
      func createUser(name: String, email: String) async throws -> User
      """,
      expandedSource: """
        func createUser(name: String, email: String) async throws -> User {
          let request = GraphQLRequest(
            query: \"\"\"
        mutation CreateUser($name: String!, $email: String!) {
          createUser(name: $name, email: $email) { id name }
        }
        \"\"\",
            variables: ["name": .string(name), "email": .string(email)],
            operationName: "CreateUser"
          )
          return try await graphQL.execute(request, as: User.self)
        }
        """,
      macros: ["Mutation": MutationMacro.self]
    )
  }

  func testMutationWithBooleanVariable() throws {
    SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
      """
      @Mutation(\"\"\"
        mutation UpdateUser($id: ID!, $active: Boolean!) {
          updateUser(id: $id, active: $active) { id }
        }
      \"\"\")
      func updateUser(id: String, active: Bool) async throws -> User
      """,
      expandedSource: """
        func updateUser(id: String, active: Bool) async throws -> User {
          let request = GraphQLRequest(
            query: \"\"\"
        mutation UpdateUser($id: ID!, $active: Boolean!) {
          updateUser(id: $id, active: $active) { id }
        }
        \"\"\",
            variables: ["id": .string(id), "active": .bool(active)],
            operationName: "UpdateUser"
          )
          return try await graphQL.execute(request, as: User.self)
        }
        """,
      macros: ["Mutation": MutationMacro.self]
    )
  }
}
#endif
