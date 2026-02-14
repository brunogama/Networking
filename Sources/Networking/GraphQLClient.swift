import Foundation

// MARK: - GraphQL Client

/// A GraphQL client built on top of ``HTTPClient``.
///
/// Provides a type-safe interface for executing GraphQL queries and mutations
/// with automatic JSON encoding/decoding and error extraction.
///
/// ## Usage
///
/// ```swift
/// let client = NetworkClient(session: .shared)
/// let graphQL = GraphQLClient(
///     httpClient: client,
///     endpoint: URL(string: "https://api.example.com/graphql")!
/// )
///
/// struct UserData: Decodable, Sendable {
///     let user: User
/// }
///
/// let response: GraphQLResponse<UserData> = try await graphQL.query(
///     """
///     query GetUser($id: ID!) {
///         user(id: $id) { id name email }
///     }
///     """,
///     variables: ["id": "123"]
/// )
///
/// if let user = response.data?.user {
///     print("Got: \(user.name)")
/// }
/// ```
public struct GraphQLClient: Sendable {
  /// The underlying HTTP client.
  private let httpClient: any HTTPClient

  /// The GraphQL endpoint URL.
  public let endpoint: URL

  /// Default HTTP headers to include in all GraphQL requests.
  public let defaultHeaders: [String: String]

  /// The JSON encoder used for request bodies.
  public let encoder: JSONEncoder

  /// The JSON decoder used for response bodies.
  public let decoder: JSONDecoder

  /// Creates a GraphQL client.
  ///
  /// - Parameters:
  ///   - httpClient: The HTTP client to use for network requests
  ///   - endpoint: The GraphQL endpoint URL
  ///   - defaultHeaders: Default headers for all requests (default: Content-Type: application/json)
  ///   - encoder: JSON encoder (default: JSONEncoder())
  ///   - decoder: JSON decoder (default: JSONDecoder())
  public init(
    httpClient: any HTTPClient,
    endpoint: URL,
    defaultHeaders: [String: String] = ["Content-Type": "application/json"],
    encoder: JSONEncoder = JSONEncoder(),
    decoder: JSONDecoder = JSONDecoder()
  ) {
    self.httpClient = httpClient
    self.endpoint = endpoint
    self.defaultHeaders = defaultHeaders
    self.encoder = encoder
    self.decoder = decoder
  }

  // MARK: - Query

  /// Executes a GraphQL query.
  ///
  /// - Parameters:
  ///   - query: The GraphQL query string
  ///   - variables: Optional variables map
  ///   - operationName: Optional operation name
  ///   - additionalHeaders: Extra headers for this specific request
  /// - Returns: A ``GraphQLResponse`` with the decoded data and/or errors
  /// - Throws: ``HTTPError`` for network errors, `DecodingError` for decode failures
  public func query<T: Decodable & Sendable>(
    _ query: String,
    variables: [String: GraphQLValue]? = nil,
    operationName: String? = nil,
    additionalHeaders: [String: String] = [:]
  ) async throws -> GraphQLResponse<T> {
    let graphQLRequest = GraphQLRequest(
      query: query,
      variables: variables,
      operationName: operationName
    )
    return try await execute(graphQLRequest, additionalHeaders: additionalHeaders)
  }

  // MARK: - Mutation

  /// Executes a GraphQL mutation.
  ///
  /// - Parameters:
  ///   - mutation: The GraphQL mutation string
  ///   - variables: Optional variables map
  ///   - operationName: Optional operation name
  ///   - additionalHeaders: Extra headers for this specific request
  /// - Returns: A ``GraphQLResponse`` with the decoded data and/or errors
  /// - Throws: ``HTTPError`` for network errors, `DecodingError` for decode failures
  public func mutate<T: Decodable & Sendable>(
    _ mutation: String,
    variables: [String: GraphQLValue]? = nil,
    operationName: String? = nil,
    additionalHeaders: [String: String] = [:]
  ) async throws -> GraphQLResponse<T> {
    let graphQLRequest = GraphQLRequest(
      query: mutation,
      variables: variables,
      operationName: operationName
    )
    return try await execute(graphQLRequest, additionalHeaders: additionalHeaders)
  }

  // MARK: - Execute

  /// Executes a ``GraphQLRequest`` and decodes the response.
  ///
  /// - Parameters:
  ///   - graphQLRequest: The GraphQL request to execute
  ///   - additionalHeaders: Extra headers for this request
  /// - Returns: A decoded ``GraphQLResponse``
  /// - Throws: ``HTTPError`` or `DecodingError`
  public func execute<T: Decodable & Sendable>(
    _ graphQLRequest: GraphQLRequest,
    additionalHeaders: [String: String] = [:]
  ) async throws -> GraphQLResponse<T> {
    let body = try encoder.encode(graphQLRequest)

    var headers = defaultHeaders
    for (name, value) in additionalHeaders {
      headers[name] = value
    }

    let httpRequest = HTTPRequest(
      method: .post,
      url: endpoint,
      headers: headers,
      body: body,
      timeout: 30.0
    )

    let response = try await httpClient.execute(httpRequest)

    guard let responseBody = response.body else {
      throw HTTPError(
        category: .decoding("Empty response body from GraphQL endpoint"),
        request: httpRequest,
        response: response
      )
    }

    return try decoder.decode(GraphQLResponse<T>.self, from: responseBody)
  }
}
