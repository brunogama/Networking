import NetworkingRuntime
import NetworkingInterceptorsCompat
import NetworkingObservability
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Mock implementation of CustomAuthProvider for testing
///
/// Provides stubbing and verification capabilities for custom authentication flows.
/// Thread-safe via DispatchQueue with concurrent reads and barrier writes.
///
/// ## Usage Example
/// ```swift
/// let mock = MockCustomAuthProvider()
///
/// // Stub authentication transform (e.g., add custom headers)
/// mock.stubAuthTransform { request in
///   var authenticated = request
///   authenticated.headers["X-Custom-Auth"] = "secret-key"
///   return authenticated
/// }
///
/// let request = HTTPRequest(method: .get, url: URL(string: "https://api.example.com")!)
/// let authenticatedRequest = try await mock.authenticateRequest(request)
/// XCTAssertEqual(authenticatedRequest.headers["X-Custom-Auth"], "secret-key")
///
/// try mock.verifyCalledOnce()
/// let captured = mock.getCapturedRequests()
/// XCTAssertEqual(captured.count, 1)
/// ```
///
/// ## Error Handling Example
/// ```swift
/// mock.stubAuthErrorHandler { request, response in
///   if response.status.rawValue == 401 {
///     var retry = request
///     retry.headers["X-Retry"] = "true"
///     return retry
///   }
///   return nil
/// }
///
/// let response = HTTPResponse(status: .unauthorized)
/// let retryRequest = await mock.handleAuthenticationError(request, response: response)
/// XCTAssertNotNil(retryRequest)
/// ```
///
/// - Note: `@unchecked Sendable` justification:
///   1. Test-only code, not production
///   2. Mutable state protected by `DispatchQueue.concurrent` with barrier writes
///   3. All public methods synchronize access through concurrent queue
///   4. Sendable closures (@Sendable) stored and invoked safely
///   5. Acceptable tradeoff for test ergonomics and API simplicity (same pattern as MockNetworkClient)
public final class MockCustomAuthProvider: CustomAuthProvider, MockVerifiable, @unchecked Sendable {
  // MARK: - Thread Safety

  private let queue = DispatchQueue(label: "mock.custom.auth.provider", attributes: .concurrent)

  // MARK: - State Tracking

  private var authTransform: (@Sendable (HTTPRequest) -> HTTPRequest)?
  private var authErrorHandler: (@Sendable (HTTPRequest, HTTPResponse) async -> HTTPRequest?)?
  private var authenticateCount: Int = 0
  private var errorHandleCount: Int = 0
  private var capturedRequests: [HTTPRequest] = []
  private var capturedErrorResponses: [(HTTPRequest, HTTPResponse)] = []

  // MARK: - Initialization

  public init() {}

  // MARK: - CustomAuthProvider Protocol

  /// Authenticate a request using stubbed transform
  ///
  /// Applies stubbed authentication transform if configured, otherwise returns request unchanged.
  /// Increments authenticate count and captures request for inspection.
  ///
  /// - Parameter request: Request to authenticate
  /// - Returns: Authenticated request (or original if no transform stubbed)
  /// - Throws: Never throws (custom auth providers handle errors via `handleAuthenticationError`)
  public func authenticateRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    // Capture request and increment count (barrier write)
    queue.sync(flags: .barrier) {
      authenticateCount += 1
      capturedRequests.append(request)
    }

    // Apply transform if stubbed (sync read)
    guard let transform = queue.sync(execute: { authTransform }) else {
      return request  // No transform stubbed, return unchanged
    }

    return transform(request)
  }

  /// Handle authentication error with stubbed error handler
  ///
  /// Calls stubbed error handler if configured, otherwise returns nil (no retry).
  /// Increments error handle count and captures error/request pair.
  ///
  /// - Parameters:
  ///   - error: Authentication error that occurred
  ///   - request: Original request that failed
  /// - Returns: Response to use instead, or nil to fail
  /// - Throws: Re-throws errors from stubbed handler
  public func handleAuthenticationError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse? {
    // Capture error and increment count (barrier write)
    queue.sync(flags: .barrier) {
      errorHandleCount += 1
      // Store error and request for inspection
      if let response = error.response {
        capturedErrorResponses.append((request, response))
      }
    }

    // Call error handler if stubbed (sync read + async call)
    guard let handler = queue.sync(execute: { authErrorHandler }) else {
      return nil  // No handler stubbed, don't retry
    }

    // Handler expects (request, response), extract response from error
    guard let response = error.response else {
      return nil  // No response in error, can't handle
    }

    // Call handler and convert return type (HTTPRequest? -> HTTPResponse?)
    // Handler returns HTTPRequest? but we return HTTPResponse?
    // If handler indicates retry (returns request), return nil to signal "retry needed"
    if await handler(request, response) != nil {
      return nil
    }

    return nil
  }

  // MARK: - Stubbing Methods

  /// Stub the authentication transform to apply to requests
  ///
  /// Transform is called synchronously during `authenticateRequest(_:)`.
  ///
  /// - Parameter transform: Closure to transform unauthenticated requests
  public func stubAuthTransform(_ transform: @escaping @Sendable (HTTPRequest) -> HTTPRequest) {
    queue.sync(flags: .barrier) {
      authTransform = transform
    }
  }

  /// Stub the error handler for authentication failures
  ///
  /// Handler is called asynchronously during `handleAuthenticationError(_:response:)`.
  /// Return nil to indicate no retry should be attempted.
  ///
  /// - Parameter handler: Async closure to handle authentication errors
  public func stubAuthErrorHandler(
    _ handler: @escaping @Sendable (HTTPRequest, HTTPResponse) async -> HTTPRequest?
  ) {
    queue.sync(flags: .barrier) {
      authErrorHandler = handler
    }
  }

  /// Stub a passthrough transform (returns request unchanged)
  ///
  /// Useful for testing scenarios where authentication is present but no-op.
  public func stubPassthrough() {
    stubAuthTransform { $0 }
  }

  /// Remove all stubbed transforms and handlers
  public func reset() {
    queue.sync(flags: .barrier) {
      authTransform = nil
      authErrorHandler = nil
      authenticateCount = 0
      errorHandleCount = 0
      capturedRequests.removeAll()
      capturedErrorResponses.removeAll()
    }
  }

  // MARK: - MockVerifiable Protocol

  /// Total number of calls made to this mock (authenticate + error handle)
  ///
  /// Conforms to `MockVerifiable` protocol for shared verification methods.
  nonisolated public var callCount: MockVerificationCount {
    get async {
      MockVerificationCount(queue.sync { authenticateCount + errorHandleCount })
    }
  }

  // MARK: - Verification Methods

  /// Verify that `authenticateRequest(_:)` was called a specific number of times
  ///
  /// - Parameter times: Expected number of authenticate calls (default: 1)
  /// - Throws: `MockError.unexpectedCallCount` if actual count doesn't match
  public func verifyAuthenticated(
    times: MockVerificationCount = MockVerificationCount(rawValue: 1)
  ) throws {
    let actual = MockVerificationCount(queue.sync { authenticateCount })
    guard actual == times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actual)
    }
  }

  /// Verify that `handleAuthenticationError(_:response:)` was called a specific number of times
  ///
  /// - Parameter times: Expected number of error handling calls (default: 1)
  /// - Throws: `MockError.unexpectedCallCount` if actual count doesn't match
  public func verifyErrorHandled(
    times: MockVerificationCount = MockVerificationCount(rawValue: 1)
  ) throws {
    let actual = MockVerificationCount(queue.sync { errorHandleCount })
    guard actual == times else {
      throw MockError.unexpectedCallCount(expected: times, actual: actual)
    }
  }

  /// Verify that neither authenticate nor error handling was called
  ///
  /// - Throws: `MockError.unexpectedCallCount` if any calls were made
  public func verifyNeverUsed() async throws {
    let total = await callCount
    guard total == 0 else {
      throw MockError.unexpectedCallCount(expected: 0, actual: total)
    }
  }

  // MARK: - Request Inspection

  /// Get all captured requests passed to `authenticateRequest(_:)`
  ///
  /// - Returns: Array of requests that were authenticated
  public func getCapturedRequests() -> [HTTPRequest] {
    queue.sync { capturedRequests }
  }

  /// Get all captured error responses passed to `handleAuthenticationError(_:response:)`
  ///
  /// - Returns: Array of (request, response) tuples for error handling calls
  public func getCapturedErrorResponses() -> [(HTTPRequest, HTTPResponse)] {
    queue.sync { capturedErrorResponses }
  }

  /// Get the count of authenticate requests
  ///
  /// - Returns: Number of times `authenticateRequest(_:)` was called
  public func getAuthenticateCount() -> MockVerificationCount {
    MockVerificationCount(queue.sync { authenticateCount })
  }

  /// Get the count of error handling calls
  ///
  /// - Returns: Number of times `handleAuthenticationError(_:response:)` was called
  public func getErrorHandleCount() -> MockVerificationCount {
    MockVerificationCount(queue.sync { errorHandleCount })
  }
}
