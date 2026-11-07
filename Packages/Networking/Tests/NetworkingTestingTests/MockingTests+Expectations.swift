import Foundation
import NetworkingCore
import NetworkingTesting
import Testing

extension MockingTests {
  @Test("MockNetworkClient basic expectations")
  func mockNetworkClientBasicExpectations() async throws {

    let mockClient = MockNetworkClient()
    let user = MockUser(id: 123, name: "Test User")

    await mockClient.expect(
      matching: .method(.get),
      .path("/users/123"),
      response: .success(statusCode: 200, data: HTTPBody(try JSONCodec().encode(user))),
      calls: .exactly(1)
    )

    let request = try HTTPRequest(
      method: .get,
      url: #require(URL(string: "https://api.example.com/users/123"))
    )

    let response = try await mockClient.execute(request)

    #expect(response.status.rawValue == 200)
    let decodedUser = try JSONDecoder().decode(MockUser.self, from: response.body!.rawValue)
    #expect(decodedUser.id == user.id)
    #expect(decodedUser.name == user.name)

    await mockClient.expectationsAreFulfilled()
  }


  @Test("MockNetworkClient call count expectations")
  func mockNetworkClientCallCountExpectations() async throws {
    let mockClient = MockNetworkClient()

    await mockClient.expect(
      matching: .method(.get),
      .path("/users"),
      response: .success(statusCode: 200, data: mockBody("[]")),
      calls: .exactly(2)
    )

    await mockClient.expect(
      matching: .method(.post),
      .path("/users"),
      response: .success(statusCode: 201, data: mockBody(#"{"id": 1}"#)),
      calls: .exactly(1)
    )

    await mockClient.expect(
      matching: .method(.delete),
      .path("/users/1"),
      response: .success(statusCode: 204, data: HTTPBody(Data())),
      calls: .exactly(0)
    )

    let url = try #require(URL(string: "https://api.example.com/users"))
    let getRequest = HTTPRequest(method: .get, url: url)
    let postRequest = HTTPRequest(method: .post, url: url)

    _ = try await mockClient.execute(getRequest)
    _ = try await mockClient.execute(getRequest)

    _ = try await mockClient.execute(postRequest)


    await mockClient.expectationsAreFulfilled()

    let history = await mockClient.getRequestHistory()
    #expect(history.count == 3)

    let usersCount = await mockClient.getRequestCount(for: "/users")
    #expect(usersCount == 3)

    let getCount = await mockClient.getRequests(
      matching: HTTPRequestPredicate { request in
        MockPredicateMatchFlag(request.method == .get && request.url.rawValue.path == "/users")
      }
    ).count
    #expect(getCount == 2)
  }


  @Test("MockNetworkClient request capture")
  func mockNetworkClientRequestCapture() async throws {
    let mockClient = MockNetworkClient()
    let (capturedRequests, capture) = AsyncStream<HTTPRequest>.makeStream()
    await mockClient.expect(
      matching: .method(.post),
      .path("/users"),
      response: .success(statusCode: 201, data: HTTPBody(Data())),
      calls: .exactly(1),
      capture: { request in
        capture.yield(request)
        capture.finish()
      }
    )

    let requestBody = Data(#"{"name": "John Doe"}"#.utf8)
    let request = HTTPRequest(
      method: .post,
      url: URL(string: "https://api.example.com/users")!,
      headers: ["Content-Type": "application/json"],
      body: requestBody
    )

    _ = try await mockClient.execute(request)

    var iterator = capturedRequests.makeAsyncIterator()
    let captured = try #require(await iterator.next())
    #expect(captured.method == .post)
    #expect(captured.body?.rawValue == requestBody)
    #expect(captured.headers["Content-Type"] == "application/json")

    await mockClient.expectationsAreFulfilled()
  }

}
