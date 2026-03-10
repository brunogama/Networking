import NetworkingRuntime
import Foundation

/// A Sendable wrapper for metadata values that can be stored in InterceptorContext.
///
/// This type allows storing various types of metadata in a thread-safe manner while
/// maintaining Swift 6 strict concurrency compliance.
@available(
  *,
  deprecated,
  message: """
    Interceptor metadata types are part of the compatibility interceptor layer.
    Prefer middleware-specific request or response context instead.
    """
)
public enum AnySendable: Sendable {
  case string(MetadataTextValue)
  case int(MetadataIntegerValue)
  case double(MetadataDecimalValue)
  case bool(MetadataFlag)
  case data(MetadataBinaryValue)
  case none

  public var stringValue: MetadataTextValue? {
    if case .string(let value) = self { return value }
    return nil
  }

  public var intValue: MetadataIntegerValue? {
    if case .int(let value) = self { return value }
    return nil
  }

  public var doubleValue: MetadataDecimalValue? {
    if case .double(let value) = self { return value }
    return nil
  }

  public var boolValue: MetadataFlag? {
    if case .bool(let value) = self { return value }
    return nil
  }

  public var dataValue: MetadataBinaryValue? {
    if case .data(let value) = self { return value }
    return nil
  }
}

/// Contextual information passed to interceptors during request/response processing.
///
/// The context provides metadata about the current request that interceptors can use
/// to make context-aware decisions. For example:
/// - A retry interceptor can check `attemptCount` to avoid infinite retry loops
/// - A rate-limiting interceptor can check `method` to apply different limits per HTTP method
/// - A logging interceptor can use `path` to filter which requests to log
///
/// ## Example: Retry with Max Attempts
///
/// ```swift
/// struct RetryInterceptor: ResponseInterceptor {
///   let maxAttempts: Int = 3
///
///   func intercept(
///     response: HTTPResponse,
///     context: InterceptorContext
///   ) async throws -> InterceptorResult {
///     // Check if we should retry
///     guard response.status.rawValue >= 500 else { return .proceed }
///
///     // Check max attempts
///     guard context.attemptCount < maxAttempts else {
///       throw InterceptorError.maxRetriesExceeded(maxAttempts: maxAttempts)
///     }
///
///     // Retry with exponential backoff
///     let delay = pow(2.0, Double(context.attemptCount))
///     return .retry(after: delay)
///   }
/// }
/// ```
///
/// ## Example: Path-Based Logging
///
/// ```swift
/// struct SelectiveLoggingInterceptor: RequestInterceptor {
///   func intercept(
///     request: inout HTTPRequest,
///     context: InterceptorContext
///   ) async throws -> InterceptorResult {
///     // Only log API requests, not health checks
///     if !context.path.contains("/health") {
///       logger("[\(context.method.rawValue)] \(context.path)")
///     }
///     return .proceed
///   }
/// }
/// ```
///
/// - Note: InterceptorContext is immutable and Sendable for thread safety.
/// - Important: The `attemptCount` increments on each retry. Always check this value
///   in retry interceptors to prevent infinite loops.
@available(
  *,
  deprecated,
  message: """
    InterceptorContext is a compatibility API.
    Prefer middleware-specific request or response context for new runtime behavior.
    """
)
public struct InterceptorContext: Sendable {
  /// The request path (e.g., "/users/123")
  public let path: RequestPathPattern

  /// The HTTP method (e.g., .get, .post)
  public let method: HTTPMethod

  /// The current attempt count (0 for first attempt, increments on each retry)
  public let attemptCount: RetryAttemptCount

  /// Additional metadata that can be used by interceptors for custom logic
  public let metadata: [InterceptorMetadataKey: AnySendable]

  /// Creates a new interceptor context.
  ///
  /// - Parameters:
  ///   - path: The request path
  ///   - method: The HTTP method
  ///   - attemptCount: The current attempt count (default: 0)
  ///   - metadata: Additional metadata (default: empty)
  public init(
    path: RequestPathPattern,
    method: HTTPMethod,
    attemptCount: RetryAttemptCount = 0,
    metadata: [InterceptorMetadataKey: AnySendable] = [:]
  ) {
    self.path = path
    self.method = method
    self.attemptCount = attemptCount
    self.metadata = metadata
  }

  package init(
    path: String,
    method: HTTPMethod,
    attemptCount: Int = 0,
    metadata: [String: AnySendable] = [:]
  ) {
    self.init(
      path: RequestPathPattern(path),
      method: method,
      attemptCount: RetryAttemptCount(attemptCount),
      metadata: Dictionary(
        uniqueKeysWithValues: metadata.map { (InterceptorMetadataKey($0.key), $0.value) }
      )
    )
  }

  /// Creates a new context with an incremented attempt count.
  ///
  /// Use this method when implementing retry logic to create a new context
  /// for the next retry attempt.
  ///
  /// - Returns: A new context with `attemptCount` incremented by 1
  public func incrementingAttempt() -> Self {
    Self(
      path: path,
      method: method,
      attemptCount: RetryAttemptCount(attemptCount.rawValue + 1),
      metadata: metadata
    )
  }

  /// Creates a new context with additional metadata.
  ///
  /// - Parameter newMetadata: Metadata to merge with existing metadata
  /// - Returns: A new context with combined metadata
  public func addingMetadata(_ newMetadata: [InterceptorMetadataKey: AnySendable]) -> Self {
    Self(
      path: path,
      method: method,
      attemptCount: attemptCount,
      metadata: metadata.merging(newMetadata) { _, newValue in newValue }
    )
  }
}
