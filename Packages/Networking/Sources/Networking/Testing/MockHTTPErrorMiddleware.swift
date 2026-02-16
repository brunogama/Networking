import Dispatch
import Foundation

/// Mock implementation of `HTTPErrorMiddleware` for testing.
///
/// `MockHTTPErrorMiddleware` allows you to stub error handling behavior
/// and verify that middleware was called in tests.
///
/// ## Example Usage
///
/// ```swift
/// let mock = MockHTTPErrorMiddleware()
/// let recoveryResponse = HTTPResponse(status: .ok, body: Data("recovered".utf8))
/// mock.stubRecoveryResponse(recoveryResponse)
///
/// let error = HTTPError.timeout
/// let response = try await mock.handleError(error, for: request)
///
/// XCTAssertEqual(mock.callCount, 1)
/// XCTAssertEqual(response, recoveryResponse)
/// ```
///
/// ## Thread Safety
///
/// This class uses `@unchecked Sendable` with a private DispatchQueue
/// to protect all mutable state. All state modifications are serialized
/// through the queue using `sync` or `async` depending on context.
public final class MockHTTPErrorMiddleware: HTTPErrorMiddleware, MockVerifiable,
  @unchecked Sendable
{
  // MARK: - Private State (Queue-Protected)

  private let queue = DispatchQueue(label: "com.networking.MockHTTPErrorMiddleware")

  private var handler: (@Sendable (Error, HTTPRequest) async throws -> HTTPResponse)?
  private var handleCount: Int = 0
  private var capturedErrors: [(error: Error, request: HTTPRequest)] = []
  private var shouldRethrow: Bool = true

  // MARK: - Initialization

  /// Creates a new mock error middleware.
  public init() {}

  // MARK: - HTTPErrorMiddleware Conformance

  /// Handles the error using the stubbed handler.
  ///
  /// - Parameters:
  ///   - error: The error to handle
  ///   - request: The original request
  /// - Returns: A recovery response (if handler is stubbed and successful)
  /// - Throws: The original error if `shouldRethrow` is true and no handler is stubbed
  public func handleError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    // Capture error and increment count
    queue.sync {
      handleCount += 1
      capturedErrors.append((error: error, request: request))
    }

    // Apply handler if stubbed
    if let handler = queue.sync(execute: { handler }) {
      return try await handler(error, request)
    }

    // Check if we should rethrow
    let rethrow = queue.sync { shouldRethrow }
    if rethrow {
      throw error
    }

    // Return default error response
    return HTTPResponse(
      status: .internalServerError,
      headers: [:],
      body: nil
    )
  }

  // MARK: - Stubbing Methods

  /// Stubs a custom error handler function.
  ///
  /// - Parameter handler: The error handler to use
  public func stubHandler(
    _ handler: @escaping @Sendable (Error, HTTPRequest) async throws -> HTTPResponse
  ) {
    queue.sync {
      self.handler = handler
    }
  }

  /// Stubs rethrow behavior (errors are rethrown).
  ///
  /// This is the default behavior. Calling this method clears any stubbed handler.
  public func stubRethrow() {
    queue.sync {
      handler = nil
      shouldRethrow = true
    }
  }

  /// Stubs swallow behavior (errors return a default response instead of rethrowing).
  ///
  /// This clears any stubbed handler and returns a default error response.
  public func stubSwallow() {
    queue.sync {
      handler = nil
      shouldRethrow = false
    }
  }

  /// Stubs a recovery response to return for all errors.
  ///
  /// This is a convenience method for the common case of returning a specific response.
  ///
  /// - Parameter response: The recovery response to return
  public func stubRecoveryResponse(_ response: HTTPResponse) {
    stubHandler { _, _ in
      response
    }
  }

  // MARK: - MockVerifiable Conformance

  /// The number of times `handleError` was called.
  public var callCount: Int {
    queue.sync { handleCount }
  }

  // MARK: - Inspection Methods

  /// Returns all captured error/request pairs in order.
  ///
  /// - Returns: An array of all error/request pairs that were handled
  public func getCapturedErrors() -> [(error: Error, request: HTTPRequest)] {
    queue.sync { capturedErrors }
  }

  /// Returns the last captured error/request pair, if any.
  ///
  /// - Returns: The most recent pair, or `nil` if none
  public func getLastCapturedError() -> (error: Error, request: HTTPRequest)? {
    queue.sync { capturedErrors.last }
  }

  // MARK: - Reset

  /// Resets all stubbed behavior and captured state.
  ///
  /// After calling `reset`, the mock returns to its initial state.
  public func reset() {
    queue.sync {
      handler = nil
      handleCount = 0
      capturedErrors.removeAll()
      shouldRethrow = true
    }
  }
}
