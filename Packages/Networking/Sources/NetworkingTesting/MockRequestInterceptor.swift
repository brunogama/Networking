import NetworkingRuntime
import NetworkingInterceptorsCompat
import NetworkingObservability
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Mock implementation of RequestInterceptor for testing request interception logic
///
/// Allows stubbing interceptor behavior with custom handlers or pre-configured actions.
/// Tracks calls and captured requests for verification.
///
/// ## Usage Example
/// ```swift
/// let mockInterceptor = MockRequestInterceptor()
///
/// // Stub to add authorization header
/// mockInterceptor.stubIntercept { request, context in
///   request.addHeader(name: "Authorization", value: "Bearer test-token")
///   return .proceed
/// }
///
/// // Use in test
/// var request = HTTPRequest(method: .get, url: URL(string: "https://api.example.com")!)
/// let result = try await mockInterceptor.intercept(request: &request, context: InterceptorContext())
///
/// // Verify
/// try mockInterceptor.verifyCalledOnce()
/// #expect(request.headers["Authorization"] == "Bearer test-token")
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
  message:
    "MockRequestInterceptor exists to support the compatibility interceptor layer. Prefer mock middleware in new tests."
)
public final class MockRequestInterceptor: RequestInterceptor, MockVerifiable, @unchecked Sendable {
  // MARK: - State

  private let queue = DispatchQueue(
    label: "MockRequestInterceptor.queue",
    attributes: .concurrent
  )

  private var _interceptHandler:
    (
      @Sendable (inout HTTPRequest, InterceptorContext) async throws ->
        InterceptorResult
    )?
  private var _interceptCount: Int = 0
  private var _capturedRequests: [HTTPRequest] = []

  // MARK: - Initialization

  public init() {}

  // MARK: - RequestInterceptor Conformance

  public func intercept(
    request: inout HTTPRequest,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    // Increment count and capture request (thread-safe)
    let handler = queue.sync(flags: .barrier) {
      () -> (@Sendable (inout HTTPRequest, InterceptorContext) async throws -> InterceptorResult)?
      in
      _interceptCount += 1
      _capturedRequests.append(request)
      return _interceptHandler
    }

    // Execute handler if set
    if let handler = handler {
      return try await handler(&request, context)
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
      @escaping @Sendable (inout HTTPRequest, InterceptorContext) async throws ->
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

  /// Stub interceptor to short-circuit with response (skip chain)
  ///
  /// - Parameter response: Response to return without proceeding
  public func stubShortCircuit(_ response: HTTPResponse) {
    queue.sync(flags: .barrier) {
      _interceptHandler = { _, _ in
        .shortCircuit(response)
      }
    }
  }

  // MARK: - MockVerifiable Conformance

  nonisolated public var callCount: Int {
    get async {
      queue.sync { _interceptCount }
    }
  }

  // MARK: - Inspection Methods

  /// Get all captured requests
  ///
  /// - Returns: Array of all requests intercepted by this mock
  public func getCapturedRequests() -> [HTTPRequest] {
    queue.sync { _capturedRequests }
  }

  /// Get request at specific index
  ///
  /// - Parameter index: Index of request to retrieve
  /// - Returns: Captured request at index, or nil if out of bounds
  public func getRequest(at index: Int) -> HTTPRequest? {
    queue.sync {
      guard index >= 0 && index < _capturedRequests.count else { return nil }
      return _capturedRequests[index]
    }
  }

  /// Get the most recent captured request
  ///
  /// - Returns: Most recent request, or nil if none captured
  public func getLastRequest() -> HTTPRequest? {
    queue.sync { _capturedRequests.last }
  }

  /// Reset all state (call count, captured requests, handler)
  public func reset() {
    queue.sync(flags: .barrier) {
      _interceptHandler = nil
      _interceptCount = 0
      _capturedRequests.removeAll()
    }
  }
}
