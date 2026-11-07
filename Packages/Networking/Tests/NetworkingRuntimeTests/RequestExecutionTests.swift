import Foundation
import NetworkingCore
import NetworkingRuntime
import NetworkingTesting
import Testing

@Suite("Declarative request execution")
struct RequestExecutionTests {
  @Test("A request materializes query items, merges configuration, and decodes its response")
  func materializesAndDecodes() async throws {
    let contextID = MockContextIdentifier()
    let url = HTTPRequestURL(
      try #require(URL(string: "https://example.com/greeting?language=swift"))
    )
    let expected = Greeting(message: "Hello")
    let codec = JSONCodec()
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }
    MockURLProtocol.stub(
      matching: .url(url),
      response: .success(statusCode: 200, data: HTTPBody(try codec.encode(expected))),
      contextID: contextID
    )

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }
    let client = NetworkClient(
      session: session,
      middleware: HTTPMiddleware(),
      configuration: configuredClient()
    )

    let response = try await client.send(GreetingRequest())
    let capturedRequests = await MockURLProtocol.getCapturedRequests(contextID: contextID)
    let captured = try #require(capturedRequests.first)
    #expect(response == expected)
    #expect(captured.url?.absoluteString == url.description)
    #expect(captured.value(forHTTPHeaderField: "Accept") == "application/json")
    #expect(captured.value(forHTTPHeaderField: "X-Client") == "Networking")
  }

  @Test("Heterogeneous requests return a typed response tuple")
  func sendsParameterPackConcurrently() async throws {
    let contextID = MockContextIdentifier()
    let greetingURL = HTTPRequestURL(
      try #require(URL(string: "https://example.com/greeting?language=swift"))
    )
    let countURL = HTTPRequestURL(try #require(URL(string: "https://example.com/count")))
    let codec = JSONCodec()
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }
    MockURLProtocol.stub(
      matching: .url(greetingURL),
      response: .success(
        statusCode: 200,
        data: HTTPBody(try codec.encode(Greeting(message: "Hello")))
      ),
      contextID: contextID
    )
    MockURLProtocol.stub(
      matching: .url(countURL),
      response: .success(statusCode: 200, data: HTTPBody(try codec.encode(ItemCount(value: 3)))),
      contextID: contextID
    )

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }
    let client = NetworkClient(
      session: session,
      middleware: HTTPMiddleware(),
      configuration: configuredClient()
    )

    let (greeting, count) = try await client.send(GreetingRequest(), CountRequest())

    #expect(greeting == Greeting(message: "Hello"))
    #expect(count == ItemCount(value: 3))
  }

  private func configuredClient() -> NetworkClient.Configuration {
    var configuration = NetworkClient.Configuration()
    configuration.baseURL = URL(string: "https://example.com")
    configuration.defaultHeaders = ["X-Client": "Networking"]
    return configuration
  }
}

private struct Greeting: Codable, Equatable, Sendable {
  let message: String
}

private struct GreetingRequest: Request {
  typealias Response = Greeting

  let method: HTTPMethod = .get
  let path: EndpointPath = "/greeting"
  let query = [HTTPQueryItem(name: "language", value: "swift")]
  let headers: HTTPHeaders = ["Accept": "application/json"]
}

private struct ItemCount: Codable, Equatable, Sendable {
  let value: Int
}

private struct CountRequest: Request {
  typealias Response = ItemCount

  let method: HTTPMethod = .get
  let path: EndpointPath = "/count"
}
