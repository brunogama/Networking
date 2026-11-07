import Foundation
import NetworkingCore
import NetworkingTesting
import Testing

extension MockingTests {
  @Test("MockURLProtocol basic stubbing")
  func mockURLProtocolBasicStubbing() async throws {
    let contextID = MockContextIdentifier()

    MockURLProtocol.clearAll(contextID: contextID)

    let testData = Data(#"{"id": 123, "name": "Test User"}"#.utf8)

    MockURLProtocol.stubSuccess(
      url: mockURL("https://api.example.com/users/123"),
      statusCode: 200,
      data: HTTPBody(testData),
      headers: ["Content-Type": "application/json"],
      contextID: contextID
    )

    let (client, session) = makeMockNetworkClient(contextID: contextID)
    defer { session.invalidateAndCancel() }
    let request = try HTTPRequest(
      method: .get,
      url: #require(URL(string: "https://api.example.com/users/123"))
    )

    let response = try await client.execute(request)

    #expect(response.status.rawValue == 200)
    #expect(response.body?.rawValue == testData)
    #expect(response.headers["Content-Type"] == "application/json")

    await MockURLProtocol.expectRequest(
      url: mockURL("https://api.example.com/users/123"),
      contextID: contextID
    )

    MockURLProtocol.clearAll(contextID: contextID)
  }


  @Test("MockURLProtocol JSON stubbing")
  func mockURLProtocolJSONStubbing() async throws {
    let contextID = MockContextIdentifier()

    MockURLProtocol.clearAll(contextID: contextID)


    let user = MockUser(id: 123, name: "Test User")

    try MockURLProtocol.stubJSON(
      url: mockURL("https://api.example.com/users/123"),
      json: user,
      contextID: contextID
    )

    let (client, session) = makeMockNetworkClient(contextID: contextID)
    defer { session.invalidateAndCancel() }
    let request = try HTTPRequest(
      method: .get,
      url: #require(URL(string: "https://api.example.com/users/123"))
    )

    let response = try await client.execute(request)

    #expect(response.status.rawValue == 200)

    let decodedUser = try JSONDecoder().decode(MockUser.self, from: response.body!.rawValue)
    #expect(decodedUser == user)

    MockURLProtocol.clearAll(contextID: contextID)
  }


  @Test("MockURLProtocol error simulation")
  func mockURLProtocolErrorSimulation() async throws {
    let contextID = MockContextIdentifier()

    MockURLProtocol.clearAll(contextID: contextID)

    MockURLProtocol.stubError(
      url: mockURL("https://api.example.com/error"),
      error: URLError(.notConnectedToInternet),
      contextID: contextID
    )

    let (client, session) = makeMockNetworkClient(contextID: contextID)
    defer { session.invalidateAndCancel() }
    let request = try HTTPRequest(
      method: .get,
      url: #require(URL(string: "https://api.example.com/error"))
    )

    await #expect(throws: HTTPError.self) {
      try await client.execute(request)
    }

    MockURLProtocol.clearAll(contextID: contextID)
  }

}
