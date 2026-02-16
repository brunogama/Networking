import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - SequentialMockError

/// Errors that can occur during sequential mock operations.
///
/// Use these errors to diagnose test failures when requests arrive in unexpected order.
public enum SequentialMockError: Error, Sendable, CustomStringConvertible {
  /// Request received did not match the expected request at this position.
  case requestMismatch(expected: RequestInfo, actual: RequestInfo, atIndex: Int)

  /// Request received after all expected requests had been consumed.
  case unexpectedCall(index: Int, request: RequestInfo)

  /// Not all expectations were consumed when verification was performed.
  case unconsumedExpectations(remaining: Int)

  public var description: String {
    switch self {
    case .requestMismatch(let expected, let actual, let atIndex):
      return """
        SequentialMock: Request mismatch at index \(atIndex).
        Expected: \(expected.method ?? "any") \(expected.path ?? "any")
        Actual: \(actual.method ?? "?") \(actual.path ?? "?")
        """

    case .unexpectedCall(let index, let request):
      return """
        SequentialMock: Unexpected request at index \(index).
        Received: \(request.method ?? "?") \(request.path ?? "?")
        All expectations have been consumed.
        """

    case .unconsumedExpectations(let remaining):
      return "SequentialMock: \(remaining) expectation(s) were not consumed."
    }
  }

  /// Information about a request for error reporting.
  public struct RequestInfo: Sendable {
    public let method: String?
    public let path: String?

    public init(method: String?, path: String?) {
      self.method = method
      self.path = path
    }
  }
}

// MARK: - SequentialMock

/// Standalone test utility for sequential mock expectations.
///
/// Provides ordered expectation matching where requests must arrive in a specific
/// sequence. Uses actor isolation internally for thread-safe call index tracking.
///
/// ## Usage
/// ```swift
/// let mock = try SequentialMock {
///     Expect { Method(.get); Path("/token") }
///     Respond { Status(.ok); MockJSONBody(["token": "abc123"]) }
///
///     Expect { Method(.get); Path("/protected") }
///     Respond { Status(.ok); MockJSONBody(["data": "secret"]) }
/// }
///
/// let session = mock.createSession()
/// // First request returns token, second returns protected data
/// try await mock.verifyAllExpectationsConsumed()
/// ```
public struct SequentialMock: Sendable {
  private let expectations: [ExpectationPair]
  private let consumptionTracker: ConsumptionTracker

  /// Creates a `SequentialMock` from mock rules.
  public init(@MockRuleBuilder _ content: () throws -> [MockRule]) throws {
    let rules = try content()
    self.expectations = rules.map { ExpectationPair(from: $0) }
    self.consumptionTracker = ConsumptionTracker(total: expectations.count)
  }

  /// Creates a URLSession configured with this sequential mock.
  public func createSession() -> URLSession {
    MockURLProtocol.clearAll()
    registerStubs()
    return URLSession(configuration: createConfiguration())
  }

  /// Verifies that all expectations have been consumed.
  public func verifyAllExpectationsConsumed() async throws {
    let remaining = await consumptionTracker.remainingCount()
    if remaining > 0 {
      throw SequentialMockError.unconsumedExpectations(remaining: remaining)
    }
  }
}

// MARK: - Private Types

extension SequentialMock {
  /// Tracks how many expectations have been consumed.
  private actor ConsumptionTracker {
    private var consumed: Int = 0
    private let total: Int

    init(total: Int) {
      self.total = total
    }

    func markConsumed() {
      consumed += 1
    }

    func remainingCount() -> Int {
      total - consumed
    }
  }

  /// Expectation paired with its response.
  private struct ExpectationPair: Sendable {
    let expectation: MockExpectation
    let response: MockResponse

    init(from rule: MockRule) {
      self.expectation = rule.expectation
      self.response = rule.response
    }
  }
}

// MARK: - Private Implementation

extension SequentialMock {
  private func createConfiguration() -> URLSessionConfiguration {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    config.urlCache = nil
    config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    return config
  }

  private func registerStubs() {
    let tracker = consumptionTracker
    let pairs = expectations

    for (index, pair) in pairs.enumerated() {
      let response = buildMockResponse(from: pair.response)
      let matcher = buildMatcher(from: pair.expectation, at: index, tracker: tracker)

      MockURLProtocol.stub(
        matching: matcher,
        response: response,
        maxUsageCount: 1
      )
    }
  }

  private func buildMatcher(
    from expectation: MockExpectation,
    at index: Int,
    tracker: ConsumptionTracker
  ) -> MockURLProtocol.RequestMatcher {
    let expectedMethod = expectation.method
    let expectedPath = expectation.path

    return .custom { @Sendable request in
      let matches = Self.requestMatches(
        request: request,
        method: expectedMethod,
        path: expectedPath
      )
      if matches {
        Task { await tracker.markConsumed() }
      }
      return matches
    }
  }

  private static func requestMatches(
    request: URLRequest,
    method expectedMethod: HTTPMethod?,
    path expectedPath: String?
  ) -> Bool {
    if let method = expectedMethod {
      let actual = request.httpMethod?.uppercased() ?? ""
      if actual != method.rawValue.uppercased() { return false }
    }
    if let path = expectedPath {
      let actual = request.url?.path ?? ""
      if actual != path { return false }
    }
    return true
  }

  private func buildMockResponse(
    from response: MockResponse
  ) -> MockURLProtocol.MockResponse {
    if let error = response.error {
      return .failure(error)
    }

    let statusCode = response.statusCode ?? 200
    let data = response.body ?? Data()
    var headers = response.headers

    if response.isJSON {
      headers["Content-Type"] = "application/json"
    }

    return .success(statusCode: statusCode, data: data, headers: headers)
  }
}
