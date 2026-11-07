import Foundation
import NetworkingCore
import NetworkingTesting
import Testing

extension MockingTests {
  @Test("MockURLProtocol timeout simulation")
  func mockURLProtocolTimeoutSimulation() async throws {
    let contextID = MockContextIdentifier()

    MockURLProtocol.clearAll(contextID: contextID)

    MockURLProtocol.stubTimeout(url: mockURL("https://api.example.com/slow"), contextID: contextID)

    let (client, session) = makeMockNetworkClient(contextID: contextID)
    defer { session.invalidateAndCancel() }
    let request = try HTTPRequest(
      method: .get,
      url: #require(URL(string: "https://api.example.com/slow"))
    )

    await #expect(throws: HTTPError.self) {
      try await client.execute(request)
    }

    MockURLProtocol.clearAll(contextID: contextID)
  }


  @Test("MockURLProtocol pattern matching")
  func mockURLProtocolPatternMatching() async throws {
    let contextID = MockContextIdentifier()

    MockURLProtocol.clearAll(contextID: contextID)

    try MockURLProtocol.stubPattern(
      "https://api\\.example\\.com/users/\\d+",
      response: .success(statusCode: 200, data: mockBody(#"{"found": true}"#)),
      contextID: contextID
    )

    let (client, session) = makeMockNetworkClient(contextID: contextID)
    defer { session.invalidateAndCancel() }

    let userIds = [123, 456, 789]
    for userId in userIds {
      let request = try HTTPRequest(
        method: .get,
        url: #require(URL(string: "https://api.example.com/users/\(userId)"))
      )

      let response = try await client.execute(request)
      #expect(response.status.rawValue == 200)

      let json = try #require(
        try JSONSerialization.jsonObject(with: response.body!.rawValue) as? [String: Any]
      )
      #expect(json["found"] as? Bool == true)
    }

    MockURLProtocol.clearAll(contextID: contextID)
  }


  @Test("MockURLProtocol sequential responses")
  func mockURLProtocolSequentialResponses() async throws {
    let contextID = MockContextIdentifier()

    MockURLProtocol.clearAll(contextID: contextID)

    MockURLProtocol.stubSequential(
      url: mockURL("https://api.example.com/counter"),
      responses: [
        .success(statusCode: 200, data: mockBody(#"{"count": 1}"#)),
        .success(statusCode: 200, data: mockBody(#"{"count": 2}"#)),
        .success(statusCode: 200, data: mockBody(#"{"count": 3}"#)),
      ],
      contextID: contextID
    )

    let config = MockURLProtocol.createMockConfiguration(contextID: contextID)
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }
    let url = URL(string: "https://api.example.com/counter")!

    var results: [Int] = []

    for _ in 1...3 {
      var urlRequest = URLRequest(url: url)
      urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
      urlRequest.httpMethod = "GET"

      let (data, _) = try await session.data(for: urlRequest)

      let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
      let actualCount = json["count"] as? Int ?? 0
      results.append(actualCount)
    }

    #expect(results == [1, 2, 3], "Expected [1, 2, 3] but got \(results)")

    MockURLProtocol.clearAll(contextID: contextID)
  }


}
