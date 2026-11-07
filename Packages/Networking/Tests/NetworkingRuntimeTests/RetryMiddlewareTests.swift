import Foundation
import NetworkingCore
import NetworkingRuntime
import Testing

struct RetryMiddlewareTests {
  @Test("Transient idempotent requests retry and retain their request identity")
  func recoversTransientFailure() async throws {
    let request = try request(method: .get)
    let transport = RetryTestTransport(failures: [.timeout])
    let middleware = RetryMiddleware(
      configuration: try .init(maxAttempts: 2, initialDelay: .zero),
      client: transport
    )

    let response = try await middleware.handleError(
      HTTPError(category: .http(.internalServerError), request: request),
      for: request
    )

    #expect(response.status == .ok)
    #expect(response.request.id == request.id)
    #expect(await transport.requests.map(\.id) == [request.id, request.id])
  }

  @Test(arguments: [HTTPMethod.post, .patch])
  func refusesImplicitReplay(method: HTTPMethod) async throws {
    let request = try request(method: method)
    let transport = RetryTestTransport(failures: [])
    let middleware = RetryMiddleware(client: transport)
    let failure = HTTPError(category: .timeout, request: request)

    await #expect(throws: HTTPError.self) {
      try await middleware.handleError(failure, for: request)
    }
    #expect(await transport.requests.isEmpty)
  }

  @Test("Explicit replay policy permits an application-approved POST")
  func permitsExplicitReplay() async throws {
    let request = try request(method: .post)
    let transport = RetryTestTransport(failures: [])
    let middleware = RetryMiddleware(
      configuration: try .init(maxAttempts: 1, initialDelay: .zero),
      client: transport,
      shouldRetry: { _, _ in true }
    )

    _ = try await middleware.handleError(HTTPError(category: .timeout), for: request)

    #expect(await transport.requests.map(\.id) == [request.id])
  }

  @Test("Retry exhaustion returns the final transport failure")
  func returnsLastFailure() async throws {
    let request = try request(method: .get)
    let transport = RetryTestTransport(failures: [.timeout, .network(.connectionLost)])
    let middleware = RetryMiddleware(
      configuration: try .init(maxAttempts: 2, initialDelay: .zero),
      client: transport
    )

    do {
      _ = try await middleware.handleError(HTTPError(category: .timeout), for: request)
      Issue.record("Expected retry exhaustion")
    } catch {
      #expect(error.category == .network(.connectionLost))
      #expect(error.request?.id == request.id)
    }
    #expect(await transport.requests.count == 2)
  }

  @Test("Cancellation is never replayed, including with a custom policy")
  func refusesCancelledFailure() async throws {
    let request = try request(method: .get)
    let transport = RetryTestTransport(failures: [])
    let middleware = RetryMiddleware(client: transport, shouldRetry: { _, _ in true })

    await #expect(throws: HTTPError.self) {
      try await middleware.handleError(HTTPError.cancelled(request: request), for: request)
    }
    #expect(await transport.requests.isEmpty)
  }

  @Test(arguments: [
    (-1, Duration.zero, Duration.zero),
    (1, Duration.seconds(-1), Duration.zero),
    (1, Duration.seconds(2), Duration.seconds(1)),
  ])
  func rejectsInvalidLimits(attempts: Int, initial: Duration, maximum: Duration) {
    #expect(throws: HTTPError.self) {
      try RetryMiddleware.Configuration(
        maxAttempts: RetryAttemptCount(attempts),
        initialDelay: initial,
        maximumDelay: maximum
      )
    }
  }

  private func request(method: HTTPMethod) throws -> HTTPRequest {
    HTTPRequest(method: method, url: try #require(URL(string: "https://retry.example.com")))
  }
}
