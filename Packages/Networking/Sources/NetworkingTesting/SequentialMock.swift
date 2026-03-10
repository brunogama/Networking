import NetworkingRuntime
import NetworkingInterceptorsCompat
import NetworkingObservability
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
  case requestMismatch(expected: RequestInfo, actual: RequestInfo, atIndex: MockRequestIndex)

  /// Request received after all expected requests had been consumed.
  case unexpectedCall(index: MockRequestIndex, request: RequestInfo)

  /// Not all expectations were consumed when verification was performed.
  case unconsumedExpectations(remaining: MockVerificationCount)

  public var description: String {
    switch self {
    case .requestMismatch(let expected, let actual, let atIndex):
      let expectedMethod = expected.method?.rawValue ?? "any"
      let expectedPath = expected.path?.rawValue ?? "any"
      let actualMethod = actual.method?.rawValue ?? "?"
      let actualPath = actual.path?.rawValue ?? "?"
      return """
        SequentialMock: Request mismatch at index \(atIndex).
        Expected: \(expectedMethod) \(expectedPath)
        Actual: \(actualMethod) \(actualPath)
        """

    case .unexpectedCall(let index, let request):
      let method = request.method?.rawValue ?? "?"
      let path = request.path?.rawValue ?? "?"
      return """
        SequentialMock: Unexpected request at index \(index).
        Received: \(method) \(path)
        All expectations have been consumed.
        """

    case .unconsumedExpectations(let remaining):
      return "SequentialMock: \(remaining) expectation(s) were not consumed."
    }
  }

  /// Information about a request for error reporting.
  public struct RequestInfo: Sendable {
    public let method: HTTPMethodName?
    public let path: MockRequestPath?

    public init(method: HTTPMethodName?, path: MockRequestPath?) {
      self.method = method
      self.path = path
    }
  }
}

// MARK: - SequentialMock

/// Standalone test utility for sequential mock expectations.
///
/// Provides ordered expectation matching where requests must arrive in a specific
/// sequence. Uses NSLock for thread-safe call index tracking.
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
  private let contextID: MockContextIdentifier

  /// Creates a `SequentialMock` from mock rules using the DSL builder.
  public init(@MockRuleBuilder _ content: () throws -> [MockRule]) throws {
    try self.init(rules: content())
  }

  /// Creates a `SequentialMock` from an array of mock rules.
  public init(rules: [MockRule]) throws {
    self.expectations = rules.map { ExpectationPair(from: $0) }
    self.consumptionTracker = ConsumptionTracker(total: expectations.count)
    self.contextID = MockContextIdentifier()
  }

  /// Creates a URLSession configured with this sequential mock.
  public func createSession() -> URLSession {
    MockURLProtocol.clearAll(contextID: contextID)
    registerStubs()
    return URLSession(configuration: createConfiguration())
  }

  /// Verifies that all expectations have been consumed.
  public func verifyAllExpectationsConsumed() async throws {
    let remaining = consumptionTracker.remainingCount()
    if remaining > 0 {
      throw SequentialMockError.unconsumedExpectations(remaining: remaining)
    }
  }
}

// MARK: - Private Types

extension SequentialMock {
  /// Tracks how many expectations have been consumed.
  ///
  /// Uses NSLock for synchronous thread-safe access since the requestCapture
  /// callback is invoked synchronously from MockURLProtocol.
  ///
  /// - Note: `@unchecked Sendable` justification:
  ///   1. Test-only code, not production
  ///   2. Mutable state (`consumed`) protected by `NSLock`
  ///   3. All access synchronized through lock
  final class ConsumptionTracker: @unchecked Sendable {
    private var consumed: MockVerificationCount = 0
    private let total: MockVerificationCount
    private let lock = NSLock()

    init(total: Int) {
      self.total = MockVerificationCount(total)
    }

    func markConsumed() {
      lock.lock()
      defer { lock.unlock() }
      consumed = MockVerificationCount(consumed.rawValue + 1)
    }

    func remainingCount() -> MockVerificationCount {
      lock.lock()
      defer { lock.unlock() }
      return total - consumed
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
    MockURLProtocol.createMockConfiguration(contextID: contextID)
  }

  private func registerStubs() {
    let tracker = consumptionTracker
    let pairs = expectations

    for pair in pairs {
      let response = buildMockResponse(from: pair.response)
      let matcher = buildMatcher(from: pair.expectation)

      // Use requestCapture to track consumption when stub is actually used
      MockURLProtocol.stub(
        matching: matcher,
        response: response,
        maxUsageCount: 1,
        requestCapture: { @Sendable _ in
          tracker.markConsumed()
        },
        contextID: contextID
      )
    }
  }

  private func buildMatcher(
    from expectation: MockExpectation
  ) -> MockURLProtocol.RequestMatcher {
    let expectedMethod = expectation.method
    let expectedPath = expectation.path

    return .custom(
      MockURLRequestPredicate { @Sendable request in
        MockPredicateMatchFlag(
          Self.requestMatches(
            request: request,
            method: expectedMethod,
            path: expectedPath
          )
        )
      }
    )
  }

  private static func requestMatches(
    request: URLRequest,
    method expectedMethod: HTTPMethod?,
    path expectedPath: MockRequestPath?
  ) -> Bool {
    if let method = expectedMethod {
      let actual = request.httpMethod?.uppercased() ?? ""
      if actual != method.rawValue.uppercased() { return false }
    }
    if let path = expectedPath {
      let actual = request.url?.path ?? ""
      if actual != path.rawValue { return false }
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
    let data = response.body ?? HTTPBody(Data())
    var headers = response.headers

    if response.isJSON.rawValue {
      headers["Content-Type"] = "application/json"
    }

    return .success(statusCode: statusCode, data: data, headers: headers)
  }
}
