import NetworkingRuntime
import NetworkingInterceptorsCompat
import NetworkingObservability
import Dispatch
import Foundation

/// Mock implementation of `HTTPResponseMiddleware` for testing.
///
/// `MockHTTPResponseMiddleware` allows you to stub response transformations
/// and verify that middleware was called in tests.
///
/// ## Example Usage
///
/// ```swift
/// let mock = MockHTTPResponseMiddleware()
/// mock.stubReplaceBody(Data("modified".utf8))
///
/// let response = HTTPResponse(status: .ok, body: Data("original".utf8))
/// let processed = try await mock.processResponse(response, for: request)
///
/// XCTAssertEqual(mock.callCount, 1)
/// XCTAssertEqual(processed.body, Data("modified".utf8))
/// ```
///
/// ## Thread Safety
///
/// This class uses `@unchecked Sendable` with a private DispatchQueue
/// to protect all mutable state. All state modifications are serialized
/// through the queue using `sync` or `async` depending on context.
public final class MockHTTPResponseMiddleware: HTTPResponseMiddleware, MockVerifiable,
  @unchecked Sendable
{
  // MARK: - Private State (Queue-Protected)

  private let queue = DispatchQueue(label: "com.networking.MockHTTPResponseMiddleware")

  private var transform: (
    @Sendable (HTTPResponse, HTTPRequest) async throws -> HTTPResponse
  )?
  private var processCount: Int = 0
  private var capturedResponses: [(request: HTTPRequest, response: HTTPResponse)] = []
  private var shouldFail: Error?

  // MARK: - Initialization

  /// Creates a new mock response middleware.
  public init() {}

  // MARK: - HTTPResponseMiddleware Conformance

  /// Processes the response using the stubbed transformation.
  ///
  /// - Parameters:
  ///   - response: The response to process
  ///   - request: The original request
  /// - Returns: The transformed response (or original if no transform stubbed)
  /// - Throws: The stubbed error if `stubFailure` was called
  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    // Capture response and increment count
    queue.sync {
      processCount += 1
      capturedResponses.append((request: request, response: response))
    }

    // Check for stubbed failure
    if let error = queue.sync(execute: { shouldFail }) {
      throw error
    }

    // Apply transform if stubbed
    if let transform = queue.sync(execute: { transform }) {
      return try await transform(response, request)
    }

    // Passthrough by default
    return response
  }

  // MARK: - Stubbing Methods

  /// Stubs a custom transformation function.
  ///
  /// - Parameter transform: The transformation to apply to responses
  public func stubTransform(
    _ transform: @escaping @Sendable (HTTPResponse, HTTPRequest) async throws -> HTTPResponse
  ) {
    queue.sync {
      self.transform = transform
    }
  }

  /// Stubs passthrough behavior (responses are returned unchanged).
  ///
  /// This clears any previously stubbed transformation.
  public func stubPassthrough() {
    queue.sync {
      transform = nil
    }
  }

  /// Stubs a failure to be thrown when processing responses.
  ///
  /// - Parameter error: The error to throw
  public func stubFailure(_ error: Error) {
    queue.sync {
      shouldFail = error
    }
  }

  /// Stubs replacing the response body.
  ///
  /// This is a convenience method for the common case of replacing body data.
  ///
  /// - Parameter body: The new body data to use
  public func stubReplaceBody(_ body: Data) {
    stubTransform { response, _ in
      HTTPResponse(
        request: response.request,
        status: response.status,
        headers: response.headers,
        body: body,
        url: response.url
      )
    }
  }

  // MARK: - MockVerifiable Conformance

  /// The number of times `processResponse` was called.
  nonisolated public var callCount: Int {
    get async { queue.sync { processCount }
    }
  }

  // MARK: - Inspection Methods

  /// Returns all captured request/response pairs in order.
  ///
  /// - Returns: An array of all request/response pairs that were processed
  public func getCapturedResponses() -> [(request: HTTPRequest, response: HTTPResponse)] {
    queue.sync { capturedResponses }
  }

  /// Returns the last captured request/response pair, if any.
  ///
  /// - Returns: The most recent pair, or `nil` if none
  public func getLastCapturedResponse() -> (request: HTTPRequest, response: HTTPResponse)? {
    queue.sync { capturedResponses.last }
  }

  // MARK: - Reset

  /// Resets all stubbed behavior and captured state.
  ///
  /// After calling `reset`, the mock returns to its initial state.
  public func reset() {
    queue.sync {
      transform = nil
      processCount = 0
      capturedResponses.removeAll()
      shouldFail = nil
    }
  }
}
