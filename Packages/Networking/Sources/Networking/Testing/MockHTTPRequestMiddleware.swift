import Dispatch
import Foundation

/// Mock implementation of `HTTPRequestMiddleware` for testing.
///
/// `MockHTTPRequestMiddleware` allows you to stub request transformations
/// and verify that middleware was called in tests.
///
/// ## Example Usage
///
/// ```swift
/// let mock = MockHTTPRequestMiddleware()
/// mock.stubAddHeader("X-Custom", value: "test-value")
///
/// let request = HTTPRequest(method: .get, url: url)
/// let processed = try await mock.modifyRequest(request)
///
/// XCTAssertEqual(mock.callCount, 1)
/// XCTAssertEqual(processed.headers["X-Custom"], "test-value")
/// ```
///
/// ## Thread Safety
///
/// This class uses `@unchecked Sendable` with a private DispatchQueue
/// to protect all mutable state. All state modifications are serialized
/// through the queue using `sync` or `async` depending on context.
public final class MockHTTPRequestMiddleware: HTTPRequestMiddleware, MockVerifiable,
  @unchecked Sendable
{
  // MARK: - Private State (Queue-Protected)

  private let queue = DispatchQueue(label: "com.networking.MockHTTPRequestMiddleware")

  private var transform: (@Sendable (HTTPRequest) async throws -> HTTPRequest)?
  private var processCount: Int = 0
  private var capturedRequests: [HTTPRequest] = []
  private var shouldFail: Error?

  // MARK: - Initialization

  /// Creates a new mock request middleware.
  public init() {}

  // MARK: - HTTPRequestMiddleware Conformance

  /// Processes the request using the stubbed transformation.
  ///
  /// - Parameter request: The request to process
  /// - Returns: The transformed request (or original if no transform stubbed)
  /// - Throws: The stubbed error if `stubFailure` was called
  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    // Capture request and increment count
    queue.sync {
      processCount += 1
      capturedRequests.append(request)
    }

    // Check for stubbed failure
    if let error = queue.sync(execute: { shouldFail }) {
      throw error
    }

    // Apply transform if stubbed
    if let transform = queue.sync(execute: { transform }) {
      return try await transform(request)
    }

    // Passthrough by default
    return request
  }

  // MARK: - Stubbing Methods

  /// Stubs a custom transformation function.
  ///
  /// - Parameter transform: The transformation to apply to requests
  public func stubTransform(
    _ transform: @escaping @Sendable (HTTPRequest) async throws -> HTTPRequest
  ) {
    queue.sync {
      self.transform = transform
    }
  }

  /// Stubs passthrough behavior (requests are returned unchanged).
  ///
  /// This clears any previously stubbed transformation.
  public func stubPassthrough() {
    queue.sync {
      transform = nil
    }
  }

  /// Stubs a failure to be thrown when processing requests.
  ///
  /// - Parameter error: The error to throw
  public func stubFailure(_ error: Error) {
    queue.sync {
      shouldFail = error
    }
  }

  /// Stubs adding a header to all processed requests.
  ///
  /// This is a convenience method for the common case of adding headers.
  ///
  /// - Parameters:
  ///   - name: The header name
  ///   - value: The header value
  public func stubAddHeader(_ name: String, value: String) {
    stubTransform { request in
      var modified = request
      modified.headers[name] = value
      return modified
    }
  }

  // MARK: - MockVerifiable Conformance

  /// The number of times `modifyRequest` was called.
  public var callCount: Int {
    queue.sync { processCount }
  }

  // MARK: - Inspection Methods

  /// Returns all captured requests in order.
  ///
  /// - Returns: An array of all requests that were processed
  public func getCapturedRequests() -> [HTTPRequest] {
    queue.sync { capturedRequests }
  }

  /// Returns the last captured request, if any.
  ///
  /// - Returns: The most recent request, or `nil` if none
  public func getLastCapturedRequest() -> HTTPRequest? {
    queue.sync { capturedRequests.last }
  }

  // MARK: - Reset

  /// Resets all stubbed behavior and captured state.
  ///
  /// After calling `reset`, the mock returns to its initial state.
  public func reset() {
    queue.sync {
      transform = nil
      processCount = 0
      capturedRequests.removeAll()
      shouldFail = nil
    }
  }
}
