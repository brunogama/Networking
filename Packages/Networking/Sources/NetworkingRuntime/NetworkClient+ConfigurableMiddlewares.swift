import Foundation

// MARK: - Configurable Middleware Implementations

/// A retry middleware that can be configured through the DSL.
struct ConfigurableRetryMiddleware: HTTPErrorMiddleware {
  let configuration: RetryConfiguration
  let client: any HTTPClient

  func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse {
    guard configuration.retryCondition(error).rawValue else {
      throw error
    }

    return try await performRetries(for: request, originalError: error)
  }

  private func performRetries(
    for request: HTTPRequest,
    originalError: HTTPError
  ) async throws -> HTTPResponse {
    var lastError = originalError

    for rawAttempt in 1...configuration.maxAttempts.rawValue {
      let attempt = RetryAttemptCount(rawAttempt)
      let delay = configuration.backoffStrategy.calculateDelay(
        for: attempt,
        baseDelay: configuration.delay
      )

      try await Task.sleep(nanoseconds: UInt64(delay.rawValue * 1_000_000_000))

      do {
        let response = try await client.execute(request)
        return response
      } catch let error as HTTPError {
        lastError = error

        // Check if we should continue retrying
        if !configuration.retryCondition(error).rawValue {
          break
        }
      } catch {
        lastError = HTTPError(
          category: .network(.serverUnreachable),
          request: request,
          underlyingError: error
        )
      }
    }

    throw lastError
  }

}
