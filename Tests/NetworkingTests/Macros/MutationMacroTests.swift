import MacroTesting
import SwiftSyntax
import SwiftSyntaxMacros
import Testing
import XCTest

@testable import NetworkingMacros

@Suite("Mutation Macro Tests")
struct MutationMacroTests {

  @Test("@Mutation generates GraphQL request")
  func mutationGeneratesRequest() {
    assertMacro(["Mutation": MutationMacro.self]) {
      #"""
      @Mutation("""
        mutation CreateUser($name: String!, $email: String!) {
          createUser(name: $name, email: $email) { id name }
        }
      """)
      func createUser(name: String, email: String) async throws -> User
      """#
    } expansion: {
      #"""
      func createUser(name: String, email: String) async throws -> User {
        let request = GraphQLRequest(
          query: """
            mutation CreateUser($name: String!, $email: String!) {
              createUser(name: $name, email: $email) { id name }
            }
          """,
          variables: ["name": .string(name), "email": .string(email)],
          operationName: "CreateUser"
        )
        return try await graphQL.execute(request, as: User.self)
      }
      """#
    }
  }

  @Test("@Mutation with boolean variable")
  func mutationWithBooleanVariable() {
    assertMacro(["Mutation": MutationMacro.self]) {
      #"""
      @Mutation("""
        mutation UpdateUser($id: ID!, $active: Boolean!) {
          updateUser(id: $id, active: $active) { id }
        }
      """)
      func updateUser(id: String, active: Bool) async throws -> User
      """#
    } expansion: {
      #"""
      func updateUser(id: String, active: Bool) async throws -> User {
        let request = GraphQLRequest(
          query: """
            mutation UpdateUser($id: ID!, $active: Boolean!) {
              updateUser(id: $id, active: $active) { id }
            }
          """,
          variables: ["id": .string(id), "active": .bool(active)],
          operationName: "UpdateUser"
        )
        return try await graphQL.execute(request, as: User.self)
      }
      """#
    }
  }

  @Test("@Mutation emits diagnostic on non-function")
  func mutationDiagnosticOnNonFunction() {
    assertMacro(["Mutation": MutationMacro.self]) {
      #"""
      @Mutation("mutation Test { test }")
      protocol NotAFunction {}
      """#
    } diagnostics: {
      #"""
      @Mutation("mutation Test { test }")
      ┬────────
      ╰─ error: @Mutation can only be applied to functions
      protocol NotAFunction {}
      """#
    }
  }
}
