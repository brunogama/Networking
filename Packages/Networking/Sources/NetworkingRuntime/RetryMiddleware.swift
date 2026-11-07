import NetworkingCore

/// Retries eligible failures with bounded exponential delays in the caller's task.
///
/// Supply a client without this middleware to avoid recursive retries. The default predicate only
/// replays idempotent methods; callers must explicitly opt other operations into replay.
public struct RetryMiddleware: HTTPErrorMiddleware {
  private let configuration: Configuration
  private let client: any HTTPClient
  private let shouldRetry: @Sendable (HTTPRequest, HTTPError) -> Bool

  public init(
    configuration: Configuration = .default,
    client: any HTTPClient,
    shouldRetry: @escaping @Sendable (HTTPRequest, HTTPError) -> Bool = Self.defaultShouldRetry
  ) {
    self.configuration = configuration
    self.client = client
    self.shouldRetry = shouldRetry
  }

  public func handleError(
    _ error: HTTPError,
    for request: HTTPRequest
  ) async throws(HTTPError) -> HTTPResponse {
    var failure = error
    var delay = configuration.initialDelay
    if Task.isCancelled { throw HTTPError.cancelled(request: request) }
    for _ in 0..<configuration.maxAttempts.rawValue {
      guard failure.category != .cancelled, shouldRetry(request, failure) else { throw failure }
      do {
        return try await execute(request, after: delay)
      } catch {
        failure = error
      }
      delay =
        delay >= configuration.maximumDelay / 2
        ? configuration.maximumDelay : delay * 2
    }
    throw failure
  }

  private func execute(
    _ request: HTTPRequest,
    after delay: Duration
  ) async throws(HTTPError) -> HTTPResponse {
    do {
      try Task.checkCancellation()
      try await Task.sleep(for: delay)
      return try await client.execute(request)
    } catch is CancellationError {
      throw HTTPError.cancelled(request: request)
    } catch let error as HTTPError {
      throw error
    } catch {
      throw HTTPError(
        category: .custom("Retry", "Retry execution failed"),
        request: request,
        underlyingError: error
      )
    }
  }

  public static func defaultShouldRetry(_ request: HTTPRequest, _ error: HTTPError) -> Bool {
    guard [HTTPMethod.get, .head, .put, .delete, .options].contains(request.method) else {
      return false
    }
    switch error.category {
    case .timeout, .network(.connectionLost), .network(.serverUnreachable):
      return true
    case .http(let status):
      return [408, 429, 500, 502, 503, 504].contains(status.rawValue.rawValue)
    default:
      return false
    }
  }
}
