import Foundation
import NetworkingCore
import NetworkingTesting
import Testing

struct ActorMockTests {
  @Test("Concurrent execution records each call against a complete expectation")
  func recordsConcurrentCalls() async throws {
    let client = MockNetworkClient()
    let request = HTTPRequest(method: .get, url: try #require(URL(string: "https://mock.test/")))
    await client.expect(matching: .method(.get), calls: .exactly(100))

    try await withThrowingTaskGroup(of: Void.self) { group in
      for _ in 0..<100 {
        group.addTask {
          let response = try await client.execute(request)
          #expect(response.request.id == request.id)
        }
      }
      try await group.waitForAll()
    }

    try await client.verifyExpectations()
    #expect(await client.getRequestHistory().count == 100)
  }

  @Test("Resetting a client leaves independently configured URLProtocol sessions intact")
  func resetIsLocalToClient() async throws {
    let context = MockContextIdentifier()
    let url = try #require(URL(string: "https://mock.test/independent"))
    defer { MockURLProtocol.clearAll(contextID: context) }
    MockURLProtocol.stubSuccess(
      url: HTTPRequestURL(url),
      data: HTTPBody(Data("kept".utf8)),
      contextID: context
    )
    await MockNetworkClient().reset()
    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: context)
    )
    defer { session.invalidateAndCancel() }

    let (data, _) = try await session.data(from: url)

    #expect(data == Data("kept".utf8))
  }

  @Test("Reset during a suspended transformation does not restore cleared history")
  func resetSurvivesSuspendedTransform() async throws {
    let middleware = MockHTTPRequestMiddleware()
    let request = HTTPRequest(method: .get, url: try #require(URL(string: "https://mock.test/")))
    let (started, notification) = AsyncStream<Void>.makeStream()
    let (released, release) = AsyncStream<Void>.makeStream()
    await middleware.stubTransform { request in
      notification.yield(())
      notification.finish()
      for await _ in released {}
      return request
    }

    try await withThrowingTaskGroup(of: HTTPRequest.self) { group in
      group.addTask { try await middleware.modifyRequest(request) }
      for await _ in started { break }
      await middleware.reset()
      release.finish()
      let response = try await group.next()
      #expect(response?.id == request.id)
    }

    #expect(await middleware.callCount == 0)
    #expect(await middleware.getCapturedRequests().isEmpty)
  }

  @Test("Cancelling a selected delayed response ends its scoped execution")
  func cancelsDelayedResponse() async throws {
    let client = MockNetworkClient()
    let request = HTTPRequest(method: .get, url: try #require(URL(string: "https://mock.test/")))
    let (started, notification) = AsyncStream<Void>.makeStream()
    await client.expect(
      matching: .method(.get),
      response: .custom(statusCode: 200, data: HTTPBody(Data()), headers: [:], delay: 60),
      calls: .exactly(1),
      capture: { _ in
        notification.yield(())
        notification.finish()
      }
    )

    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        await #expect(throws: CancellationError.self) { try await client.execute(request) }
      }
      for await _ in started { break }
      group.cancelAll()
    }
    try await client.verifyExpectations()
  }
}
