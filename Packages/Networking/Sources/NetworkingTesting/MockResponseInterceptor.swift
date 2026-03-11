import NetworkingRuntime
import NetworkingInterceptorsCompat
import NetworkingObservability
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Mock implementation of ResponseInterceptor for testing response interception logic
///
/// Allows stubbing interceptor behavior with custom handlers or pre-configured actions.
/// Tracks calls and captured responses for verification.
///
/// ## Usage Example
/// ```swift
/// let mockInterceptor = MockResponseInterceptor()
///
/// // Stub to detect 401 and trigger retry
/// mockInterceptor.stubIntercept { response, request, context in
///   if response.status.rawValue == 401 {
///     return .retry(after: nil)
///   }
///   return .proceed
/// }
///
/// // Use in test
/// let response = HTTPResponse(status: .unauthorized)
/// let result = try await mockInterceptor.intercept(
///   response: response,
///   context: InterceptorContext()
/// )
///
/// // Verify
/// try mockInterceptor.verifyCalledOnce()
/// #expect(result == .retry(after: nil))
/// ```
///
/// - Note: `@unchecked Sendable` justification:
///   1. Test-only code, not production
///   2. Mutable state protected by `DispatchQueue.concurrent` with barrier writes
///   3. All public methods synchronize access through queue
///   4. Acceptable tradeoff for test ergonomics
@available(
  *,
  deprecated,
  message: """
    MockResponseInterceptor exists to support the compatibility interceptor layer. \
    Prefer mock middleware in new tests.
    """
)
public final class MockResponseInterceptor: ResponseInterceptor, MockVerifiable, @unchecked Sendable
{
  // MARK: - State

  private let queue = DispatchQueue(
    label: "MockResponseInterceptor.queue",
    attributes: .concurrent
  )

  private var _interceptHandler:
    (
      @Sendable (HTTPResponse, InterceptorContext) async throws ->
        InterceptorResult
    )?
  private var _interceptCount: Int = 0
  private var _capturedResponses: [HTTPResponse] = []

  // MARK: - Initialization

  public init() {}

  // MARK: - ResponseInterceptor Conformance

  public func intercept(
    response: HTTPResponse,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    // Increment count and capture response (thread-safe)
    let handler = queue.sync(flags: .barrier) {
      () -> (@Sendable (HTTPResponse, InterceptorContext) async throws -> InterceptorResult)? in
      _interceptCount += 1
      // Store both response and original request from context
      _capturedResponses.append(response)
      return _interceptHandler
    }

    // Execute handler if set
    if let handler = handler {
      return try await handler(response, context)
    }

    // Default: proceed with chain
    return .proceed
  }

  // MARK: - Stubbing Methods

  /// Stub interceptor with custom handler
  ///
  /// - Parameter handler: Custom interception logic
  public func stubIntercept(
    _ handler:
      @escaping @Sendable (HTTPResponse, InterceptorContext) async throws ->
      InterceptorResult
  ) {
    queue.sync(flags: .barrier) {
      _interceptHandler = handler
    }
  }

  /// Stub interceptor to proceed with chain (clears custom handler)
  public func stubProceed() {
    queue.sync(flags: .barrier) {
      _interceptHandler = nil
    }
  }

  /// Stub interceptor to replace response with different response
  ///
  /// - Parameter response: Replacement response to return
  public func stubReplace(_ response: HTTPResponse) {
    queue.sync(flags: .barrier) {
      _interceptHandler = { _, _ in
        .shortCircuit(response)
      }
    }
  }

  /// Stub interceptor to trigger retry
  ///
  /// - Parameter delay: Optional retry delay
  public func stubRetry(after delay: MockTimeAdjustment? = nil) {
    queue.sync(flags: .barrier) {
      _interceptHandler = { _, _ in
        .retry(after: delay.map { RetryDelay($0.rawValue) })
      }
    }
  }

  // MARK: - MockVerifiable Conformance

  nonisolated public var callCount: MockVerificationCount {
    get async {
      MockVerificationCount(queue.sync { _interceptCount })
    }
  }

  // MARK: - Inspection Methods

  /// Get all captured responses
  ///
  /// - Returns: Array of captured responses (each response contains its request)
  public func getCapturedResponses() -> [HTTPResponse] {
    queue.sync { _capturedResponses }
  }

  /// Get response at specific index
  ///
  /// - Parameter index: Index of response to retrieve
  /// - Returns: Captured response at index, or nil if out of bounds
  public func getResponse(at index: MockResponseIndex) -> HTTPResponse? {
    queue.sync {
      let rawIndex = index.rawValue
      guard rawIndex >= 0 && rawIndex < _capturedResponses.count else { return nil }
      return _capturedResponses[rawIndex]
    }
  }

  /// Get the most recent captured response
  ///
  /// - Returns: Most recent response, or nil if none captured
  public func getLastResponse() -> HTTPResponse? {
    queue.sync { _capturedResponses.last }
  }

  /// Reset all state (call count, captured responses, handler)
  public func reset() {
    queue.sync(flags: .barrier) {
      _interceptHandler = nil
      _interceptCount = 0
      _capturedResponses.removeAll()
    }
  }
}
