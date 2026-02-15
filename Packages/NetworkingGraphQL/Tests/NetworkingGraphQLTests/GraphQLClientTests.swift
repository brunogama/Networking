import Testing
import Foundation
@testable import NetworkingGraphQL
import Networking  // For MockNetworkClient if needed

@Suite("GraphQL Tests")
struct GraphQLClientTests {

  // MARK: - GraphQLValue Tests

  @Test("GraphQLValue string literal")
  func testStringLiteral() throws {
    let value: GraphQLValue = "hello"
    if case .string(let s) = value {
      #expect(s == "hello")
    } else {
      Issue.record("Expected .string")
    }
  }

  @Test("GraphQLValue integer literal")
  func testIntegerLiteral() throws {
    let value: GraphQLValue = 42
    if case .int(let i) = value {
      #expect(i == 42)
    } else {
      Issue.record("Expected .int")
    }
  }

  @Test("GraphQLValue float literal")
  func testFloatLiteral() throws {
    let value: GraphQLValue = 3.14
    if case .double(let d) = value {
      #expect(d == 3.14)
    } else {
      Issue.record("Expected .double")
    }
  }

  @Test("GraphQLValue bool literal")
  func testBoolLiteral() throws {
    let value: GraphQLValue = true
    if case .bool(let b) = value {
      #expect(b == true)
    } else {
      Issue.record("Expected .bool")
    }
  }

  @Test("GraphQLValue array literal")
  func testArrayLiteral() throws {
    let value: GraphQLValue = ["a", "b", "c"]
    if case .list(let arr) = value {
      #expect(arr.count == 3)
    } else {
      Issue.record("Expected .list")
    }
  }

  @Test("GraphQLValue dictionary literal")
  func testDictionaryLiteral() throws {
    let value: GraphQLValue = ["name": "Test", "age": 25]
    if case .object(let dict) = value {
      #expect(dict.count == 2)
    } else {
      Issue.record("Expected .object")
    }
  }

  @Test("GraphQLValue null")
  func testNull() throws {
    let value = GraphQLValue.null
    if case .null = value {
      // Expected
    } else {
      Issue.record("Expected .null")
    }
  }

  @Test("GraphQLValue encodes to JSON")
  func testEncoding() throws {
    let value = GraphQLValue.object([
      "name": .string("Alice"),
      "age": .int(30),
      "active": .bool(true),
    ])

    let data = try JSONEncoder().encode(value)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(json["name"] as? String == "Alice")
    #expect(json["age"] as? Int == 30)
    #expect(json["active"] as? Bool == true)
  }

  // MARK: - GraphQLRequest Tests

  @Test("GraphQLRequest encodes correctly")
  func testRequestEncoding() throws {
    let request = GraphQLRequest(
      query: "query { users { id name } }",
      variables: ["limit": 10],
      operationName: "GetUsers"
    )

    let data = try JSONEncoder().encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(json["query"] as? String == "query { users { id name } }")
    #expect(json["operationName"] as? String == "GetUsers")
    #expect(json["variables"] != nil)
  }

  @Test("GraphQLRequest without variables")
  func testRequestWithoutVariables() throws {
    let request = GraphQLRequest(query: "{ currentUser { name } }")

    let data = try JSONEncoder().encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(json["query"] as? String == "{ currentUser { name } }")
  }

  // MARK: - GraphQLResponse Tests

  @Test("GraphQLResponse decodes data")
  func testResponseDecodesData() throws {
    struct UserData: Decodable, Sendable {
      let name: String
    }

    let json = #"{"data": {"name": "Alice"}}"#
    let response = try JSONDecoder().decode(
      GraphQLResponse<UserData>.self,
      from: json.data(using: .utf8)!
    )

    #expect(response.data?.name == "Alice")
    #expect(!response.hasErrors)
    #expect(response.errors == nil)
  }

  @Test("GraphQLResponse decodes errors")
  func testResponseDecodesErrors() throws {
    struct Empty: Decodable, Sendable {}

    let json = #"""
      {
        "data": null,
        "errors": [
          {
            "message": "User not found",
            "locations": [{"line": 2, "column": 3}],
            "path": ["user"]
          }
        ]
      }
      """#

    let response = try JSONDecoder().decode(
      GraphQLResponse<Empty>.self,
      from: json.data(using: .utf8)!
    )

    #expect(response.data == nil)
    #expect(response.hasErrors)
    #expect(response.errors?.count == 1)
    #expect(response.errors?.first?.message == "User not found")
    #expect(response.errors?.first?.locations?.first?.line == 2)
    #expect(response.errors?.first?.locations?.first?.column == 3)
  }

  @Test("GraphQLError path with string and index components")
  func testErrorPathComponents() throws {
    struct Empty: Decodable, Sendable {}

    let json = #"""
      {
        "data": null,
        "errors": [
          {
            "message": "Field error",
            "path": ["users", 0, "email"]
          }
        ]
      }
      """#

    let response = try JSONDecoder().decode(
      GraphQLResponse<Empty>.self,
      from: json.data(using: .utf8)!
    )

    let path = response.errors?.first?.path
    #expect(path?.count == 3)
    #expect(path?[0] == .field("users"))
    #expect(path?[1] == .index(0))
    #expect(path?[2] == .field("email"))
  }

  // MARK: - GraphQLClient Tests

  @Test("GraphQLClient query sends POST request")
  func testQuerySendsPost() async throws {
    struct UserData: Decodable, Sendable {
      let user: User
      struct User: Decodable, Sendable {
        let id: String
        let name: String
      }
    }

    let mockClient = MockNetworkClient()
    let responseJSON = #"{"data": {"user": {"id": "123", "name": "Alice"}}}"#

    mockClient.expectPOST("/graphql")
      .andReturn(
        .success(
          statusCode: 200,
          data: responseJSON.data(using: .utf8)!,
          headers: ["Content-Type": "application/json"]
        )
      )

    let graphQL = GraphQLClient(
      httpClient: mockClient,
      endpoint: URL(string: "https://api.example.com/graphql")!
    )

    let response: GraphQLResponse<UserData> = try await graphQL.query(
      "query GetUser($id: ID!) { user(id: $id) { id name } }",
      variables: ["id": "123"],
      operationName: "GetUser"
    )

    #expect(response.data?.user.id == "123")
    #expect(response.data?.user.name == "Alice")
  }

  @Test("GraphQLClient mutate sends POST request")
  func testMutateSendsPost() async throws {
    struct CreateResult: Decodable, Sendable {
      let createUser: CreatedUser
      struct CreatedUser: Decodable, Sendable {
        let id: String
      }
    }

    let mockClient = MockNetworkClient()
    let responseJSON = #"{"data": {"createUser": {"id": "456"}}}"#

    mockClient.expectPOST("/graphql")
      .andReturn(
        .success(
          statusCode: 200,
          data: responseJSON.data(using: .utf8)!,
          headers: ["Content-Type": "application/json"]
        )
      )

    let graphQL = GraphQLClient(
      httpClient: mockClient,
      endpoint: URL(string: "https://api.example.com/graphql")!
    )

    let response: GraphQLResponse<CreateResult> = try await graphQL.mutate(
      """
      mutation CreateUser($name: String!) {
          createUser(name: $name) { id }
      }
      """,
      variables: ["name": "Bob"]
    )

    #expect(response.data?.createUser.id == "456")
  }

  @Test("GraphQLClient handles error response")
  func testHandlesErrorResponse() async throws {
    struct Empty: Decodable, Sendable {}

    let mockClient = MockNetworkClient()
    let errorJSON = #"{"data": null, "errors": [{"message": "Unauthorized"}]}"#

    mockClient.expectPOST("/graphql")
      .andReturn(
        .success(
          statusCode: 200,
          data: errorJSON.data(using: .utf8)!
        )
      )

    let graphQL = GraphQLClient(
      httpClient: mockClient,
      endpoint: URL(string: "https://api.example.com/graphql")!
    )

    let response: GraphQLResponse<Empty> = try await graphQL.query("{ protected }")
    #expect(response.hasErrors)
    #expect(response.errors?.first?.message == "Unauthorized")
  }

  @Test("GraphQLClient includes default headers")
  func testIncludesDefaultHeaders() async throws {
    struct Empty: Decodable, Sendable {}

    let mockClient = MockNetworkClient()

    // The mock will receive the request with Content-Type header
    mockClient.expectPOST("/graphql")
      .andReturn(.success(statusCode: 200, data: #"{"data": null}"#.data(using: .utf8)!))
      .capture { request in
        // Verify Content-Type is set
        #expect(request.headers["Content-Type"] == "application/json")
      }

    let graphQL = GraphQLClient(
      httpClient: mockClient,
      endpoint: URL(string: "https://api.example.com/graphql")!
    )

    let _: GraphQLResponse<Empty> = try await graphQL.query("{ test }")
  }
}
