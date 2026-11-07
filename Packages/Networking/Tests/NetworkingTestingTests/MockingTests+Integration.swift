import Foundation
import NetworkingCore
import NetworkingRuntime
import NetworkingTesting
import Testing

extension MockingTests {
  @Test("Integration: MockURLProtocol with NetworkClient")
  func integrationWithNetworkClient() async throws {
    let contextID = MockContextIdentifier()

    MockURLProtocol.clearAll(contextID: contextID)


    let user = MockUser(id: 123, name: "Test User", email: "test@example.com")

    try MockURLProtocol.stubJSON(
      url: mockURL("https://api.example.com/users/123"),
      json: user,
      contextID: contextID
    )

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }
    let httpClient = NetworkClient(session: session)

    let request = try HTTPRequest(
      method: .get,
      url: #require(URL(string: "https://api.example.com/users/123")),
      headers: ["Accept": "application/json"]
    )

    let response = try await httpClient.execute(request)

    #expect(response.status.rawValue == 200)
    let decodedUser = try JSONDecoder().decode(MockUser.self, from: response.body!.rawValue)
    #expect(decodedUser == user)

    MockURLProtocol.clearAll(contextID: contextID)
  }


  @Test("Integration: Sequential failure and recovery")
  func sequentialFailureThenRecovery() async throws {
    let contextID = MockContextIdentifier()

    MockURLProtocol.clearAll(contextID: contextID)

    MockURLProtocol.stubSequential(
      url: mockURL("https://api.example.com/retry-test"),
      responses: [
        .failure(URLError(.networkConnectionLost)),
        .success(statusCode: 200, data: mockBody(#"{"success": true}"#)),
      ],
      contextID: contextID
    )

    let (client, session) = makeMockNetworkClient(contextID: contextID)
    defer { session.invalidateAndCancel() }

    let request = try HTTPRequest(
      method: .get,
      url: #require(URL(string: "https://api.example.com/retry-test"))
    )

    await #expect(throws: HTTPError.self) {
      try await client.execute(request)
    }

    let response = try await client.execute(request)
    #expect(response.status.rawValue == 200)

    let json = try #require(
      try JSONSerialization.jsonObject(with: response.body!.rawValue) as? [String: Any]
    )
    #expect(json["success"] as? Bool == true)

    MockURLProtocol.clearAll(contextID: contextID)
  }
}
