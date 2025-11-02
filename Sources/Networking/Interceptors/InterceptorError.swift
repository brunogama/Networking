import Foundation

/// Errors that can occur during interceptor chain execution.
///
/// These errors provide detailed diagnostic information about interceptor failures,
/// making it easier to debug issues in production.
///
/// ## Example: Handling Max Retries
///
/// ```swift
/// do {
///   let user = try await apiClient.getUser(id: "123")
/// } catch let error as InterceptorError {
///   switch error {
///   case .maxRetriesExceeded(let maxAttempts):
///     logger.error("Request failed after \(maxAttempts) attempts")
///   case .interceptorFailed(let underlyingError):
///     logger.error("Interceptor failed: \(underlyingError)")
///   case .invalidResult(let reason):
///     logger.error("Invalid interceptor result: \(reason)")
///   }
/// }
/// ```
public enum InterceptorError: Error, Sendable {
  /// The maximum number of retry attempts was exceeded.
  ///
  /// This error occurs when a response interceptor returns `.retry()` too many times,
  /// exceeding the configured maximum retry limit (typically 3 attempts).
  ///
  /// - Parameter maxAttempts: The maximum number of attempts that was configured
  case maxRetriesExceeded(maxAttempts: Int)

  /// An interceptor threw an error during execution.
  ///
  /// This wraps any error thrown by an interceptor's `intercept()` method,
  /// preserving the original error for debugging while clearly indicating
  /// that the failure occurred in an interceptor.
  ///
  /// - Parameter underlyingError: The original error thrown by the interceptor
  case interceptorFailed(underlyingError: Error)

  /// An interceptor returned an invalid result.
  ///
  /// This error occurs when an interceptor returns a result that doesn't make sense
  /// in the current context, such as:
  /// - A request interceptor returning `.shortCircuit(nil)`
  /// - A response interceptor returning `.shortCircuit` with an invalid response
  ///
  /// - Parameter reason: A human-readable explanation of why the result was invalid
  case invalidResult(reason: String)
}

// MARK: - LocalizedError Conformance

extension InterceptorError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .maxRetriesExceeded(let maxAttempts):
      return """
        Maximum retry attempts (\(maxAttempts)) exceeded. \
        The request was retried \(maxAttempts) times but continued to fail.
        """

    case .interceptorFailed(let underlyingError):
      return """
        Interceptor execution failed: \(underlyingError.localizedDescription). \
        Check the interceptor implementation for errors.
        """

    case .invalidResult(let reason):
      return """
        Invalid interceptor result: \(reason). \
        The interceptor returned an unexpected or malformed result.
        """
    }
  }

  public var failureReason: String? {
    switch self {
    case .maxRetriesExceeded:
      return "The maximum number of retry attempts was exceeded"

    case .interceptorFailed:
      return "An interceptor threw an error during execution"

    case .invalidResult:
      return "An interceptor returned an invalid result"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .maxRetriesExceeded:
      return """
        Check network connectivity and server status. \
        Consider increasing the max retry limit if transient errors are expected.
        """

    case .interceptorFailed:
      return """
        Review the interceptor's implementation and ensure it handles all error cases correctly. \
        Check logs for the underlying error details.
        """

    case .invalidResult:
      return """
        Review the interceptor's logic to ensure it returns valid InterceptorResult values. \
        Ensure .shortCircuit results include a valid HTTPResponse.
        """
    }
  }
}
