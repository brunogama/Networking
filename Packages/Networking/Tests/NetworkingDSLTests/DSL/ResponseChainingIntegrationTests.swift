import Foundation
@testable import NetworkingDSL
import NetworkingRuntime
import NetworkingRuntimeDSL
import NetworkingTesting
import Testing

/// Integration tests for response chaining with actual caching and retry behavior
struct ResponseChainingIntegrationTests {
    // MARK: - Test Fixtures

    struct User: Codable, Sendable, Equatable {
        let id: Int
        let name: String
    }

    // MARK: - Retry Tests

    @Test("Retryable request retries on 500 error")
    func retryableRequestRetriesOnServerError() async throws {
        // Create mock client that fails twice then succeeds
        let mockClient = RetryTestClient(failuresBeforeSuccess: 2)

        let request = HTTPRequest(
            method: .get,
            url: URL(string: "https://api.example.com/users/1")!
        )

        let result = try await request
            .prepare(for: User.self)
            .retryable(maxAttempts: 3)
            .execute(on: mockClient)

        #expect(result.value == User(id: 1, name: "Test User"))
        #expect(await mockClient.currentAttemptCount == 3) // 2 failures + 1 success
    }

    @Test("Retryable request fails after max attempts exhausted")
    func retryableRequestFailsAfterMaxAttempts() async throws {
        let mockClient = RetryTestClient(failuresBeforeSuccess: 5)

        let request = HTTPRequest(
            method: .get,
            url: URL(string: "https://api.example.com/users/1")!
        )

        await #expect(throws: HTTPError.self) {
            _ = try await request
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
            _ = try await request
                .prepare(for: User.self)
                .retryable(maxAttempts: 3)
                .execute(on: mockClient)
        }

        #expect(await mockClient.currentAttemptCount == 1) // No retries for client errors
    }

    @Test("Retryable request retries on 429 rate limit")
    func retryableRequestRetriesOnRateLimit() async throws {
        let mockClient = RateLimitTestClient(rateLimitCountBeforeSuccess: 2)

        let request = HTTPRequest(
            method: .get,
            url: URL(string: "https://api.example.com/users/1")!
        )

        let result = try await request
            .prepare(for: User.self)
            .retryable(maxAttempts: 5)
            .execute(on: mockClient)

        #expect(result.value.id == 1)
        #expect(await mockClient.currentAttemptCount == 3) // 2 rate limits + 1 success
    }

    // MARK: - Chaining Tests

    @Test("Full chain with cacheable and retryable executes correctly")
    func fullChainExecutesCorrectly() async throws {
        let mockClient = SuccessfulTestClient()

        let request = HTTPRequest(
            method: .get,
            url: URL(string: "https://api.example.com/users/1")!
        )

        let result = try await request
            .prepare(for: User.self)
            .cacheable(ttl: 300)
            .retryable(maxAttempts: 3)
            .execute(on: mockClient)

        #expect(result.value == User(id: 1, name: "Test User"))
        #expect(result.status == .ok)
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

        let result = try await request
            .prepare(for: SnakeCaseUser.self, using: decoder)
            .execute(on: mockClient)

        #expect(result.value == SnakeCaseUser(userId: 1, fullName: "Test User"))
    }

    // MARK: - Value Access Tests

    @Test("ChainedRequest result provides access to response metadata")
    func chainedRequestResultProvidesMetadata() async throws {
        let mockClient = SuccessfulTestClient()

        let request = HTTPRequest(
            method: .get,
            url: URL(string: "https://api.example.com/users/1")!
        )

        let result = try await request
            .prepare(for: User.self)
            .execute(on: mockClient)

        #expect(result.status == .ok)
        #expect(result.headers["Content-Type"] == "application/json")
        #expect(result.requestURL.absoluteString == "https://api.example.com/users/1")
    }

    // MARK: - Error Tests

    @Test("ChainedRequest throws on empty response body")
    func chainedRequestThrowsOnEmptyBody() async throws {
        let mockClient = EmptyBodyTestClient()

        let request = HTTPRequest(
            method: .get,
            url: URL(string: "https://api.example.com/users/1")!
        )

        await #expect(throws: HTTPError.self) {
            _ = try await request
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
            _ = try await request
                .prepare(for: User.self)
                .execute(on: mockClient)
        }
    }
}

// MARK: - Test Clients

/// Mock client that fails a specified number of times with 500 error before succeeding
private actor RetryTestClient: HTTPClient {
    private let failuresBeforeSuccess: Int
    private var attemptCount = 0

    var currentAttemptCount: Int {
        attemptCount
    }

    init(failuresBeforeSuccess: Int) {
        self.failuresBeforeSuccess = failuresBeforeSuccess
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        attemptCount += 1
        let currentAttempt = attemptCount

        if currentAttempt <= failuresBeforeSuccess {
            throw HTTPError(
                category: .http(.internalServerError),
                request: request
            )
        }

        let userData = #"{"id": 1, "name": "Test User"}"#.data(using: .utf8)!
        return HTTPResponse(
            request: request,
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: userData
        )
    }
}

/// Mock client that returns 400 Bad Request
private actor ClientErrorTestClient: HTTPClient {
    private var attemptCount = 0

    var currentAttemptCount: Int {
        attemptCount
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        attemptCount += 1

        throw HTTPError(
            category: .http(.badRequest),
            request: request
        )
    }
}

/// Mock client that returns 429 rate limit before succeeding
private actor RateLimitTestClient: HTTPClient {
    private let rateLimitCountBeforeSuccess: Int
    private var attemptCount = 0

    var currentAttemptCount: Int {
        attemptCount
    }

    init(rateLimitCountBeforeSuccess: Int) {
        self.rateLimitCountBeforeSuccess = rateLimitCountBeforeSuccess
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        attemptCount += 1
        let currentAttempt = attemptCount

        if currentAttempt <= rateLimitCountBeforeSuccess {
            throw HTTPError(
                category: .http(.tooManyRequests),
                request: request
            )
        }

        let userData = #"{"id": 1, "name": "Test User"}"#.data(using: .utf8)!
        return HTTPResponse(
            request: request,
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: userData
        )
    }
}

/// Mock client that always succeeds
private final class SuccessfulTestClient: HTTPClient, Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        let userData = #"{"id": 1, "name": "Test User"}"#.data(using: .utf8)!
        return HTTPResponse(
            request: request,
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: userData
        )
    }
}

/// Mock client returning snake_case JSON
private final class SnakeCaseTestClient: HTTPClient, Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        let userData = #"{"user_id": 1, "full_name": "Test User"}"#.data(using: .utf8)!
        return HTTPResponse(
            request: request,
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: userData
        )
    }
}

/// Mock client returning empty body
private final class EmptyBodyTestClient: HTTPClient, Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        HTTPResponse(
            request: request,
            status: .ok,
            headers: [:],
            body: Data()
        )
    }
}

/// Mock client returning invalid JSON
private final class InvalidJSONTestClient: HTTPClient, Sendable {
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        HTTPResponse(
            request: request,
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: "not valid json".data(using: .utf8)!
        )
    }
}
