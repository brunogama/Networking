import Foundation
import NetworkingCore
import NetworkingTesting
import Testing

extension MockingTests {
  @Test("MockNetworkClient request history filtering")
  func mockNetworkClientRequestHistoryFiltering() async throws {
    let mockClient = MockNetworkClient()

    await mockClient.stubGET(path: "/users", response: HTTPBody(Data()))
    await mockClient.stubGET(path: "/posts", response: HTTPBody(Data()))
    await mockClient.stubPOST(path: "/users", response: HTTPBody(Data()))

    let requests: [HTTPRequest] = try [
      HTTPRequest(method: .get, url: #require(URL(string: "https://api.example.com/users"))),
      HTTPRequest(method: .get, url: #require(URL(string: "https://api.example.com/posts"))),
      HTTPRequest(method: .get, url: #require(URL(string: "https://api.example.com/users"))),
      HTTPRequest(method: .post, url: #require(URL(string: "https://api.example.com/users"))),
    ]

    for request in requests {
      _ = try await mockClient.execute(request)
    }

    let allRequests = await mockClient.getRequestHistory()
    #expect(allRequests.count == 4)

    let getRequests = await mockClient.getRequests(
      matching: HTTPRequestPredicate { request in
        MockPredicateMatchFlag(request.method == .get)
      }
    )
    #expect(getRequests.count == 3)

    let userRequests = await mockClient.getRequests(
      matching: HTTPRequestPredicate { request in
        MockPredicateMatchFlag(request.url.rawValue.path == "/users")
      }
    )
    #expect(userRequests.count == 3)

    let postRequests = await mockClient.getRequests(
      matching: HTTPRequestPredicate { request in
        MockPredicateMatchFlag(request.method == .post)
      }
    )
    #expect(postRequests.count == 1)

    let userCount = await mockClient.getRequestCount(for: "/users")
    #expect(userCount == 3)

    let postCount = await mockClient.getRequestCount(for: "/posts")
    #expect(postCount == 1)
  }


  @Test("MockNetworkClient unfulfilled expectations")
  func mockNetworkClientUnfulfilledExpectations() async throws {
    let mockClient = MockNetworkClient()

    await mockClient.expect(
      matching: .method(.get),
      .path("/users"),
      response: .success(statusCode: 200, data: HTTPBody(Data())),
      calls: .exactly(2)
    )

    await mockClient.expect(
      matching: .method(.post),
      .path("/posts"),
      response: .success(statusCode: 201, data: HTTPBody(Data())),
      calls: .exactly(1)
    )

    let request = try HTTPRequest(
      method: .get,
      url: #require(URL(string: "https://api.example.com/users"))
    )
    _ = try await mockClient.execute(request)

    #expect(await !mockClient.areExpectationsFulfilled().rawValue)

    let unfulfilled = await mockClient.getUnfulfilledExpectations()
    #expect(unfulfilled.count == 2)

    await #expect(throws: AssertionError.self) {
      try await mockClient.verifyExpectations()
    }
  }


  @Test("MockNetworkClient reset functionality")
  func mockNetworkClientResetFunctionality() async throws {
    let mockClient = MockNetworkClient()

    await mockClient.expect(
      matching: .method(.get),
      .path("/test"),
      response: .success(statusCode: 200, data: HTTPBody(Data())),
      calls: .exactly(2)
    )

    let request = try HTTPRequest(
      method: .get,
      url: #require(URL(string: "https://api.example.com/test"))
    )
    _ = try await mockClient.execute(request)

    #expect(await mockClient.getRequestHistory().count == 1)
    #expect(await !mockClient.getUnfulfilledExpectations().isEmpty)

    await mockClient.reset()

    #expect(await mockClient.getRequestHistory().isEmpty)
    #expect(await mockClient.areExpectationsFulfilled().rawValue)  // No expectations = fulfilled
  }


}
