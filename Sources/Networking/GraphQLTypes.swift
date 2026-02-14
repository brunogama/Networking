import Foundation

// MARK: - GraphQL Types

/// A GraphQL request body.
///
/// Encapsulates the query/mutation string, variables, and operation name.
///
/// ```swift
/// let request = GraphQLRequest(
///     query: """
///     query GetUser($id: ID!) {
///         user(id: $id) {
///             id
///             name
///             email
///         }
///     }
///     """,
///     variables: ["id": "123"],
///     operationName: "GetUser"
/// )
/// ```
public struct GraphQLRequest: Sendable, Encodable {
  /// The GraphQL query or mutation string.
  public let query: String

  /// Variables to be injected into the query.
  public let variables: [String: GraphQLValue]?

  /// The name of the operation to execute (for multi-operation documents).
  public let operationName: String?

  /// Creates a GraphQL request.
  ///
  /// - Parameters:
  ///   - query: The GraphQL query or mutation string
  ///   - variables: Optional variables map
  ///   - operationName: Optional operation name
  public init(
    query: String,
    variables: [String: GraphQLValue]? = nil,
    operationName: String? = nil
  ) {
    self.query = query
    self.variables = variables
    self.operationName = operationName
  }
}

// MARK: - GraphQL Value

/// A type-safe representation of GraphQL variable values.
public enum GraphQLValue: Sendable, Encodable {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  case null
  case list([Self])
  case object([String: Self])

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value):
      try container.encode(value)
    case .int(let value):
      try container.encode(value)
    case .double(let value):
      try container.encode(value)
    case .bool(let value):
      try container.encode(value)
    case .null:
      try container.encodeNil()
    case .list(let values):
      try container.encode(values)
    case .object(let dict):
      try container.encode(dict)
    }
  }
}

// MARK: - ExpressibleByLiteral Conformances

extension GraphQLValue: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self = .string(value)
  }
}

extension GraphQLValue: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self = .int(value)
  }
}

extension GraphQLValue: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self = .double(value)
  }
}

extension GraphQLValue: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self = .bool(value)
  }
}

extension GraphQLValue: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: GraphQLValue...) {
    self = .list(elements)
  }
}

extension GraphQLValue: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, GraphQLValue)...) {
    self = .object(Dictionary(uniqueKeysWithValues: elements))
  }
}

// MARK: - GraphQL Response

/// A GraphQL response envelope.
///
/// Contains the response data (if successful) and any errors returned
/// by the server.
///
/// ```swift
/// let response: GraphQLResponse<UserData> = try await graphQL.query(...)
/// if let user = response.data?.user {
///     print("Got user: \(user.name)")
/// }
/// if let errors = response.errors {
///     for error in errors {
///         print("Error: \(error.message)")
///     }
/// }
/// ```
public struct GraphQLResponse<T: Decodable & Sendable>: Sendable {
  /// The decoded response data, if present.
  public let data: T?

  /// GraphQL errors returned by the server.
  public let errors: [GraphQLError]?

  /// Whether the response contains errors.
  public var hasErrors: Bool {
    errors?.isEmpty == false
  }
}

extension GraphQLResponse: Decodable {
  private enum CodingKeys: String, CodingKey {
    case data
    case errors
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    data = try container.decodeIfPresent(T.self, forKey: .data)
    errors = try container.decodeIfPresent([GraphQLError].self, forKey: .errors)
  }
}

// MARK: - GraphQL Error

/// A GraphQL error as specified by the GraphQL specification.
///
/// See: https://spec.graphql.org/October2021/#sec-Errors
public struct GraphQLError: Error, Sendable, Decodable, Equatable {
  /// The error message.
  public let message: String

  /// Locations in the query where the error occurred.
  public let locations: [Location]?

  /// The path to the field that produced the error.
  public let path: [PathComponent]?

  /// A location in a GraphQL document.
  public struct Location: Sendable, Decodable, Equatable {
    public let line: Int
    public let column: Int
  }

  /// A component in a GraphQL error path.
  public enum PathComponent: Sendable, Decodable, Equatable {
    case field(String)
    case index(Int)

    public init(from decoder: any Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let string = try? container.decode(String.self) {
        self = .field(string)
      } else if let int = try? container.decode(Int.self) {
        self = .index(int)
      } else {
        throw DecodingError.dataCorruptedError(
          in: container,
          debugDescription: "Path component must be a string or integer"
        )
      }
    }
  }
}
