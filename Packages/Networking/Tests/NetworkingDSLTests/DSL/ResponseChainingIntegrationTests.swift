import Foundation
@testable import NetworkingDSL
import NetworkingRuntime
import NetworkingRuntimeDSL
import NetworkingTesting
import Testing

struct ResponseChainingIntegrationTests {

  struct User: Codable, Sendable, Equatable {
    let id: Int
    let name: String
  }

  @Test("Retryable request retries on 500 error")
  func retryableRequestRetriesOnServerError() async throws {
    let mockClient = RetryTestClient(failuresBeforeSuccess: 2)

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users/1")!
    )

    let result =
      try await request
      .prepare(for: User.self)
      .retryable(maxAttempts: 3)
      .execute(on: mockClient)

    #expect(result.value == User(id: 1, name: "Test User"))
    #expect(await mockClient.currentAttemptCount == 3)
  }

  @Test("Retryable request fails after max attempts exhausted")
  func retryableRequestFailsAfterMaxAttempts() async throws {
    let mockClient = RetryTestClient(failuresBeforeSuccess: 5)

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users/1")!
    )

    await #expect(throws: HTTPError.self) {
      _ =
        try await request
        .prepare(for: User.self)
        .retryable(maxAttempts: 3)
        .execute(on: mockClient)
    }

    #expect(await mockClient.currentAttemptCount == 3)
  }

  @Test("Retryable request does not retry on 400 client error")
  func retryableRequestDoesNotRetryOnClientError() async throws {
    let mockClient = ClientErrorTestClient()

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users/1")!
    )

    await #expect(throws: HTTPError.self) {
      _ =
        try await request
        .prepare(for: User.self)
        .retryable(maxAttempts: 3)
        .execute(on: mockClient)
    }

    #expect(await mockClient.currentAttemptCount == 1)
  }

  @Test("Retryable request retries on 429 rate limit")
  func retryableRequestRetriesOnRateLimit() async throws {
    let mockClient = RateLimitTestClient(rateLimitCountBeforeSuccess: 2)

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users/1")!
    )

    let result =
      try await request
      .prepare(for: User.self)
      .retryable(maxAttempts: 5)
      .execute(on: mockClient)

    #expect(result.value.id == 1)
    #expect(await mockClient.currentAttemptCount == 3)
  }

  @Test("Full chain with cacheable and retryable executes correctly")
  func fullChainExecutesCorrectly() async throws {
    let mockClient = SuccessfulTestClient()

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users/1")!
    )

    let result =
      try await request
      .prepare(for: User.self)
      .cacheable(ttl: 300)
      .retryable(maxAttempts: 3)
      .execute(on: mockClient)

    #expect(result.value == User(id: 1, name: "Test User"))
    #expect(result.status == .ok)
  }

  @Test("Cacheable chain serves a second execution without a second request")
  func cacheableChainReusesResponse() async throws {
    let client = CountingSuccessClient()
    let url = try #require(URL(string: "https://api.example.com/users/1"))
    let request = HTTPRequest(method: .get, url: url)
    let chain = request.prepare(for: User.self).cacheable(ttl: 300)

    let first = try await chain.execute(on: client)
    let second = try await chain.execute(on: client)

    #expect(first.value == second.value)
    #expect(await client.count == 1)
  }

  @Test("A cacheable chain does not share a response across clients")
  func cacheableChainIsClientScoped() async throws {
    let firstClient = CountingSuccessClient()
    let secondClient = CountingSuccessClient()
    let url = try #require(URL(string: "https://api.example.com/users/1"))
    let chain = HTTPRequest(method: .get, url: url)
      .prepare(for: User.self)
      .cacheable(ttl: 300)

    _ = try await chain.execute(on: firstClient)
    _ = try await chain.execute(on: secondClient)

    #expect(await firstClient.count == 1)
    #expect(await secondClient.count == 1)
  }

  @Test("Prepare with custom decoder uses that decoder")
  func prepareWithCustomDecoder() async throws {
    let mockClient = SnakeCaseTestClient()

    struct SnakeCaseUser: Codable, Sendable, Equatable {
      let userId: Int
      let fullName: String
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users/1")!
    )

    let result =
      try await request
      .prepare(for: SnakeCaseUser.self, using: decoder)
      .execute(on: mockClient)

    #expect(result.value == SnakeCaseUser(userId: 1, fullName: "Test User"))
  }

  @Test("ChainedRequest result provides access to response metadata")
  func chainedRequestResultProvidesMetadata() async throws {
    let mockClient = SuccessfulTestClient()

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users/1")!
    )

    let result =
      try await request
      .prepare(for: User.self)
      .execute(on: mockClient)

    #expect(result.status == .ok)
    #expect(result.headers["Content-Type"] == "application/json")
    #expect(result.requestURL.absoluteString == "https://api.example.com/users/1")
  }

  @Test("ChainedRequest throws on empty response body")
  func chainedRequestThrowsOnEmptyBody() async throws {
    let mockClient = EmptyBodyTestClient()

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users/1")!
    )

    await #expect(throws: HTTPError.self) {
      _ =
        try await request
        .prepare(for: User.self)
        .execute(on: mockClient)
    }
  }

  @Test("ChainedRequest throws on decode failure")
  func chainedRequestThrowsOnDecodeFailure() async throws {
    let mockClient = InvalidJSONTestClient()

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users/1")!
    )

    await #expect(throws: HTTPError.self) {
      _ =
        try await request
        .prepare(for: User.self)
        .execute(on: mockClient)
    }
  }
}
