import Foundation

/// Generates a GraphQL query function body from the query string.
///
/// Maps function parameters to GraphQL variables automatically.
///
/// Example:
/// ```swift
/// @Query("""
///   query GetUser($id: ID!) {
///     user(id: $id) { id name email }
///   }
/// """)
/// func getUser(id: String) async throws -> User
/// ```
///
/// Expands to:
/// ```swift
/// func getUser(id: String) async throws -> User {
///   let request = GraphQLRequest(
///     query: """
///       query GetUser($id: ID!) {
///         user(id: $id) { id name email }
///       }
///     """,
///     variables: ["id": .string(id)],
///     operationName: "GetUser"
///   )
///   return try await graphQL.execute(request, as: User.self)
/// }
/// ```
@attached(body)
public macro Query(
  _ query: String
) = #externalMacro(module: "NetworkingGraphQLMacros", type: "QueryMacro")

/// Generates a GraphQL mutation function body from the mutation string.
///
/// Maps function parameters to GraphQL variables automatically.
///
/// Example:
/// ```swift
/// @Mutation("""
///   mutation CreateUser($name: String!, $email: String!) {
///     createUser(name: $name, email: $email) { id }
///   }
/// """)
/// func createUser(name: String, email: String) async throws -> User
/// ```
///
/// Expands to:
/// ```swift
/// func createUser(name: String, email: String) async throws -> User {
///   let request = GraphQLRequest(
///     query: """
///       mutation CreateUser($name: String!, $email: String!) {
///         createUser(name: $name, email: $email) { id }
///       }
///     """,
///     variables: ["name": .string(name), "email": .string(email)],
///     operationName: "CreateUser"
///   )
///   return try await graphQL.execute(request, as: User.self)
/// }
/// ```
@attached(body)
public macro Mutation(
  _ mutation: String
) = #externalMacro(module: "NetworkingGraphQLMacros", type: "MutationMacro")
