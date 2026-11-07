import Foundation
import NetworkingCore
import NetworkingTesting
import Testing

extension MockingTests {
  @Test("MockNetworkClient error expectations")
  func mockNetworkClientErrorExpectations() async throws {
    let mockClient = MockNetworkClient()

    await mockClient.expect(
      matching: .method(.get),
      .path("/error"),
      response: .failure(URLError(.networkConnectionLost)),
      calls: .exactly(1)
    )

    let request = try HTTPRequest(
      method: .get,
      url: #require(URL(string: "https://api.example.com/error"))
    )

    await #expect(throws: HTTPError.self) {
      try await mockClient.execute(request)
    }

    await mockClient.expectationsAreFulfilled()
  }


  @Test("MockNetworkClient timeout expectations")
  func mockNetworkClientTimeoutExpectations() async throws {
    let mockClient = MockNetworkClient()

    await mockClient.expect(
      matching: .method(.get),
      .path("/slow"),
      response: .timeout,
      calls: .exactly(1)
    )

    let request = try HTTPRequest(
      method: .get,
      url: #require(URL(string: "https://api.example.com/slow"))
    )

    await #expect(throws: HTTPError.self) {
      try await mockClient.execute(request)
    }

    await mockClient.expectationsAreFulfilled()
  }


  @Test("MockNetworkClient convenience methods")
  func mockNetworkClientConvenienceMethods() async throws {

    let mockClient = MockNetworkClient()
    let user = MockUser(id: 123, name: "Test User")

    try await mockClient.stubGET(path: "/users/123", json: user)
    await mockClient.stubPOST(path: "/users", response: HTTPBody(Data(#"{"id": 456}"#.utf8)))

    let getRequest = try HTTPRequest(
      method: .get,
      url: #require(URL(string: "https://api.example.com/users/123"))
    )
    let postRequest = try HTTPRequest(
      method: .post,
      url: #require(URL(string: "https://api.example.com/users"))
    )

    let getResponse = try await mockClient.execute(getRequest)
    let postResponse = try await mockClient.execute(postRequest)

    #expect(getResponse.status.rawValue == 200)
    #expect(postResponse.status.rawValue == 201)

    let decodedUser = try JSONDecoder().decode(MockUser.self, from: getResponse.body!.rawValue)
    #expect(decodedUser.id == user.id)

    let postResult = try #require(
      try JSONSerialization.jsonObject(with: postResponse.body!.rawValue) as? [String: Any]
    )
    #expect(postResult["id"] as? Int == 456)
  }

}
