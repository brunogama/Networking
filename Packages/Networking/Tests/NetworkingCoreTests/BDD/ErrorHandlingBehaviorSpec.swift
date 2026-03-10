import Foundation
import Testing

@testable import NetworkingCore

struct HTTPStatusExpectation: Sendable {
  let code: Int
  let expected: HTTPStatus
  let isServerError: Bool
}

struct ClientErrorContextExpectation: Sendable {
  let code: Int
  let expected: HTTPStatus
  let method: HTTPMethod
  let path: String
}

enum RetryableErrorExpectation: String, CaseIterable, Sendable {
  case timeout
  case serviceUnavailable
  case rateLimit
  case network

  var request: HTTPRequest {
    switch self {
    case .timeout:
      return ErrorHandlingBehaviorTests.makeRequest(path: "/timeout")
    case .serviceUnavailable:
      return ErrorHandlingBehaviorTests.makeRequest(path: "/unavailable")
    case .rateLimit:
      return ErrorHandlingBehaviorTests.makeRequest(path: "/rate-limited")
    case .network:
      return ErrorHandlingBehaviorTests.makeRequest(path: "/offline")
    }
  }

  var error: HTTPError {
    switch self {
    case .timeout:
      return HTTPError(category: .timeout, request: request)
    case .serviceUnavailable:
      return HTTPError(category: .http(.serviceUnavailable), request: request)
    case .rateLimit:
      return HTTPError(category: .http(.tooManyRequests), request: request)
    case .network:
      return HTTPError(category: .network(.connectionLost), request: request)
    }
  }

  var expectedStatus: HTTPStatus? {
    switch self {
    case .timeout, .network:
      return nil
    case .serviceUnavailable:
      return .serviceUnavailable
    case .rateLimit:
      return .tooManyRequests
    }
  }
}

/// BDD specs for error handling behaviors
///
/// These specs describe observable error handling behaviors:
/// - HTTP error classification (4xx client, 5xx server)
/// - Error recovery strategies
/// - Retryable vs non-retryable error detection
///
/// NOTE: Supplements existing error handling tests with behavior-focused specs.
@Suite("Error handling")
struct ErrorHandlingBehaviorTests {
  @Test(
    "Classifies representative 4xx client errors",
    arguments: [
      HTTPStatusExpectation(code: 400, expected: .badRequest, isServerError: false),
      HTTPStatusExpectation(code: 401, expected: .unauthorized, isServerError: false),
      HTTPStatusExpectation(code: 404, expected: .notFound, isServerError: false),
      HTTPStatusExpectation(code: 429, expected: .tooManyRequests, isServerError: false),
    ]
  )
  func classifiesClientErrors(expectation: HTTPStatusExpectation) {
    let status = HTTPStatus(rawValue: expectation.code)
    let error = HTTPError(category: .http(status))

    #expect(status == expectation.expected)
    #expect(status.isClientError)
    #expect(status.isServerError == expectation.isServerError)

    guard case .http(let errorStatus) = error.category else {
      Issue.record("Expected HTTP error category")
      return
    }

    #expect(errorStatus == status)
  }

  @Test(
    "Classifies representative 5xx server errors",
    arguments: [
      HTTPStatusExpectation(code: 500, expected: .internalServerError, isServerError: true),
      HTTPStatusExpectation(code: 502, expected: .badGateway, isServerError: true),
      HTTPStatusExpectation(code: 503, expected: .serviceUnavailable, isServerError: true),
      HTTPStatusExpectation(code: 504, expected: .gatewayTimeout, isServerError: true),
    ]
  )
  func classifiesServerErrors(expectation: HTTPStatusExpectation) {
    let status = HTTPStatus(rawValue: expectation.code)

    #expect(status == expectation.expected)
    #expect(status.isServerError == expectation.isServerError)
    #expect(!status.isClientError)
  }

  @Test("Recognizes retryable recovery cases", arguments: RetryableErrorExpectation.allCases)
  func recognizesRetryableRecoveryCases(expectation: RetryableErrorExpectation) {
    let error = expectation.error

    if let expectedStatus = expectation.expectedStatus {
      guard case .http(let status) = error.category else {
        Issue.record("Expected HTTP status category")
        return
      }

      #expect(status == expectedStatus)
    }

    #expect(error.recoveryCategory != .nonRecoverable)
  }

  @Test(
    "Preserves client status semantics for auth and validation failures",
    arguments: [
      ClientErrorContextExpectation(
        code: 401,
        expected: .unauthorized,
        method: .get,
        path: "/protected"
      ),
      ClientErrorContextExpectation(
        code: 400,
        expected: .badRequest,
        method: .post,
        path: "/create"
      ),
      ClientErrorContextExpectation(
        code: 404,
        expected: .notFound,
        method: .get,
        path: "/missing"
      ),
    ]
  )
  func preservesClientStatusSemantics(expectation: ClientErrorContextExpectation) {
    let request = Self.makeRequest(path: expectation.path, method: expectation.method)
    let error = HTTPError(
      category: .http(HTTPStatus(rawValue: expectation.code)),
      request: request
    )

    guard case .http(let status) = error.category else {
      Issue.record("Expected HTTP status category")
      return
    }

    #expect(status == expectation.expected)
    #expect(status.isClientError)
    #expect(error.request?.url.path == expectation.path)
  }

  @Test("Preserves the original request in timeout errors")
  func preservesTheOriginalRequestInTheError() {
    let url = URL(string: "https://api.example.com/data")!
    let request = HTTPRequest(
      method: .post,
      url: url,
      headers: ["Content-Type": "application/json"],
      body: Data("{\"key\": \"value\"}".utf8)
    )
    let error = HTTPError(category: .timeout, request: request)

    guard let preservedRequest = error.request else {
      Issue.record("Expected request context to be preserved")
      return
    }

    #expect(preservedRequest.url == url)
    #expect(preservedRequest.method == .post)
  }

  @Test("Preserves HTTP status in HTTP errors")
  func preservesHTTPStatusInTheError() {
    let error = HTTPError(category: .http(HTTPStatus(rawValue: 502)))

    guard case .http(let errorStatus) = error.category else {
      Issue.record("Expected HTTP error with status")
      return
    }

    #expect(errorStatus.rawValue == 502)
    #expect(errorStatus.isServerError)
  }

  @Test("Distinguishes network errors from HTTP errors")
  func distinguishesNetworkErrorsFromHTTPErrors() {
    let networkError = HTTPError(category: .network(.connectionLost))
    let httpError = HTTPError(category: .http(.internalServerError))

    guard case .network = networkError.category else {
      Issue.record("Expected network error category")
      return
    }

    guard case .http = httpError.category else {
      Issue.record("Expected HTTP error category")
      return
    }
  }

  @Test("Distinguishes timeout from other errors")
  func distinguishesTimeoutFromOtherErrors() {
    let timeoutError = HTTPError(category: .timeout)

    guard case .timeout = timeoutError.category else {
      Issue.record("Expected timeout error category")
      return
    }
  }

  fileprivate static func makeRequest(
    path: String,
    method: HTTPMethod = .get
  ) -> HTTPRequest {
    HTTPRequest(method: method, url: URL(string: "https://api.example.com\(path)")!)
  }
}
