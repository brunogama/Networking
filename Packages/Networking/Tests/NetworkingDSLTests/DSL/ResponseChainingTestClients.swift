import Foundation
import NetworkingCore
import NetworkingRuntime

actor RetryTestClient: HTTPClient {
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

    let userData = Data(#"{"id": 1, "name": "Test User"}"#.utf8)
    return HTTPResponse(
      request: request,
      status: .ok,
      headers: ["Content-Type": "application/json"],
      body: userData
    )
  }
}

actor ClientErrorTestClient: HTTPClient {
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

actor RateLimitTestClient: HTTPClient {
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

    let userData = Data(#"{"id": 1, "name": "Test User"}"#.utf8)
    return HTTPResponse(
      request: request,
      status: .ok,
      headers: ["Content-Type": "application/json"],
      body: userData
    )
  }
}

final class SuccessfulTestClient: HTTPClient, Sendable {
  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    let userData = Data(#"{"id": 1, "name": "Test User"}"#.utf8)
    return HTTPResponse(
      request: request,
      status: .ok,
      headers: ["Content-Type": "application/json"],
      body: userData
    )
  }
}

actor CountingSuccessClient: HTTPClient {
  private(set) var count = 0

  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    count += 1
    return HTTPResponse(
      request: request,
      status: .ok,
      headers: ["Content-Type": "application/json"],
      body: Data(#"{"id": 1, "name": "Test User"}"#.utf8)
    )
  }
}

final class SnakeCaseTestClient: HTTPClient, Sendable {
  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    let userData = Data(#"{"user_id": 1, "full_name": "Test User"}"#.utf8)
    return HTTPResponse(
      request: request,
      status: .ok,
      headers: ["Content-Type": "application/json"],
      body: userData
    )
  }
}

final class EmptyBodyTestClient: HTTPClient, Sendable {
  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    HTTPResponse(
      request: request,
      status: .ok,
      headers: [:],
      body: Data()
    )
  }
}

final class InvalidJSONTestClient: HTTPClient, Sendable {
  func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
    HTTPResponse(
      request: request,
      status: .ok,
      headers: ["Content-Type": "application/json"],
      body: Data("not valid json".utf8)
    )
  }
}
