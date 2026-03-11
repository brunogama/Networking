// swiftlint:disable file_length
import Foundation
import NetworkingCore

// MARK: - Decoded Response

/// A response that has been decoded to a typed value.
/// Preserves access to original HTTPResponse metadata while providing decoded value.
public struct DecodedResponse<T: Sendable>: Sendable {
  /// The original HTTP response
  public let response: HTTPResponse

  /// The decoded value
  public let value: T

  // Pass-through accessors for common response properties
  public var status: HTTPStatus { response.status }
  public var headers: HTTPHeaders { response.headers }
  public var requestURL: HTTPRequestURL { response.request.url }

  public init(response: HTTPResponse, value: T) {
    self.response = response
    self.value = value
  }
}

// MARK: - Chain Methods on DecodedResponse

extension DecodedResponse {
  /// Marks this response for caching with the specified configuration.
  /// - Parameter ttl: Time-to-live in seconds (default: 300)
  /// - Returns: CacheableResponse wrapping this decoded response
  public func cacheable(
    ttl: NetworkingCore.RequestTimeout = NetworkingCore.RequestTimeout(300)
  ) -> CacheableResponse<T> {
    CacheableResponse(decoded: self, ttl: ttl)
  }

  /// Marks this response as retryable with specified max attempts.
  /// - Parameter maxAttempts: Maximum retry attempts (default: 3)
  /// - Returns: RetryableResponse wrapping this decoded response
  public func retryable(
    maxAttempts: RetryAttemptCount = RetryAttemptCount(rawValue: 3)
  ) -> RetryableResponse<T> {
    RetryableResponse(decoded: self, maxAttempts: maxAttempts)
  }

  /// Maps the decoded value to a new type.
  /// - Parameter transform: Transformation closure
  /// - Returns: DecodedResponse with transformed value
  public func map<U: Sendable>(
    _ transform: (T) throws -> U
  ) rethrows -> DecodedResponse<U> {
    DecodedResponse<U>(response: response, value: try transform(value))
  }

  /// Applies a validation that throws on failure.
  /// - Parameter validation: Validation closure
  /// - Returns: Self if validation passes
  public func validated(
    _ validation: (T) throws -> Void
  ) rethrows -> Self {
    try validation(value)
    return self
  }
}

// MARK: - Cacheable Response

/// A decoded response with caching configuration attached.
public struct CacheableResponse<T: Sendable>: Sendable {
  public let decoded: DecodedResponse<T>
  public let ttl: NetworkingCore.RequestTimeout

  // Pass-through accessors
  public var value: T { decoded.value }
  public var response: HTTPResponse { decoded.response }
  public var status: HTTPStatus { decoded.status }
  public var headers: HTTPHeaders { decoded.headers }

  public init(decoded: DecodedResponse<T>, ttl: NetworkingCore.RequestTimeout) {
    self.decoded = decoded
    self.ttl = ttl
  }

  /// Chain to add retry configuration
  public func retryable(
    maxAttempts: RetryAttemptCount = RetryAttemptCount(rawValue: 3)
  ) -> RetryableCacheableResponse<T> {
    RetryableCacheableResponse(cacheable: self, maxAttempts: maxAttempts)
  }
}

// MARK: - Retryable Response

/// A decoded response with retry configuration attached.
public struct RetryableResponse<T: Sendable>: Sendable {
  public let decoded: DecodedResponse<T>
  public let maxAttempts: RetryAttemptCount

  // Pass-through accessors
  public var value: T { decoded.value }
  public var response: HTTPResponse { decoded.response }
  public var status: HTTPStatus { decoded.status }
  public var headers: HTTPHeaders { decoded.headers }

  public init(decoded: DecodedResponse<T>, maxAttempts: RetryAttemptCount) {
    self.decoded = decoded
    self.maxAttempts = maxAttempts
  }

  /// Chain to add caching configuration
  public func cacheable(
    ttl: NetworkingCore.RequestTimeout = NetworkingCore.RequestTimeout(300)
  ) -> RetryableCacheableResponse<T> {
    RetryableCacheableResponse(
      cacheable: CacheableResponse(decoded: decoded, ttl: ttl),
      maxAttempts: maxAttempts
    )
  }
}

// MARK: - Combined Response

/// A response with both caching and retry configuration.
public struct RetryableCacheableResponse<T: Sendable>: Sendable {
  public let cacheable: CacheableResponse<T>
  public let maxAttempts: RetryAttemptCount

  // Pass-through accessors
  public var value: T { cacheable.value }
  public var response: HTTPResponse { cacheable.response }
  public var status: HTTPStatus { cacheable.status }
  public var headers: HTTPHeaders { cacheable.headers }
  public var ttl: NetworkingCore.RequestTimeout { cacheable.ttl }

  public init(cacheable: CacheableResponse<T>, maxAttempts: RetryAttemptCount) {
    self.cacheable = cacheable
    self.maxAttempts = maxAttempts
  }
}

// MARK: - Chained Request

/// A request with attached configuration for caching and retry behavior.
///
/// This type enables pre-execution configuration of HTTP requests using a fluent API.
/// Unlike post-response wrappers, ChainedRequest captures configuration that affects
/// request execution (caching, retries) before the request is sent.
///
/// Example:
/// ```swift
/// let user = try await request
///   .prepare(for: User.self)
///   .cacheable(ttl: 300)
///   .retryable(maxAttempts: 3)
///   .execute(on: client)
///   .value
/// ```
public struct ChainedRequest<T: Decodable & Sendable>: Sendable {
  /// The HTTP request to execute
  public let request: HTTPRequest

  /// JSON decoder for response body
  public let decoder: JSONDecoder

  /// Optional caching configuration
  public let cacheConfig: CacheConfiguration?

  /// Optional retry configuration
  public let retryConfig: RetryConfiguration?

  /// Configuration for response caching
  public struct CacheConfiguration: Sendable {
    /// Time-to-live in seconds for cached responses
    public let ttl: NetworkingCore.RequestTimeout

    public init(ttl: NetworkingCore.RequestTimeout) {
      self.ttl = ttl
    }
  }

  /// Configuration for request retry behavior
  public struct RetryConfiguration: Sendable {
    /// Maximum number of retry attempts
    public let maxAttempts: RetryAttemptCount

    /// Base delay for exponential backoff in seconds
    public let baseDelay: RetryDelay

    /// Maximum delay cap in seconds
    public let maxDelay: RetryDelay

    public init(
      maxAttempts: RetryAttemptCount,
      baseDelay: RetryDelay = 1.0,
      maxDelay: RetryDelay = 60.0
    ) {
      self.maxAttempts = maxAttempts
      self.baseDelay = baseDelay
      self.maxDelay = maxDelay
    }
  }

  public init(
    request: HTTPRequest,
    decoder: JSONDecoder = JSONDecoder(),
    cacheConfig: CacheConfiguration? = nil,
    retryConfig: RetryConfiguration? = nil
  ) {
    self.request = request
    self.decoder = decoder
    self.cacheConfig = cacheConfig
    self.retryConfig = retryConfig
  }

  /// Adds caching configuration to the request.
  /// - Parameter ttl: Time-to-live in seconds (default: 300)
  /// - Returns: New ChainedRequest with caching enabled
  public func cacheable(
    ttl: NetworkingCore.RequestTimeout = NetworkingCore.RequestTimeout(300)
  ) -> ChainedRequest<T> {
    Self(
      request: request,
      decoder: decoder,
      cacheConfig: CacheConfiguration(ttl: ttl),
      retryConfig: retryConfig
    )
  }

  /// Adds retry configuration to the request.
  /// - Parameters:
  ///   - maxAttempts: Maximum retry attempts (default: 3)
  ///   - baseDelay: Base delay for exponential backoff (default: 1.0)
  ///   - maxDelay: Maximum delay cap (default: 60.0)
  /// - Returns: New ChainedRequest with retry enabled
  public func retryable(
    maxAttempts: RetryAttemptCount = 3,
    baseDelay: RetryDelay = 1.0,
    maxDelay: RetryDelay = 60.0
  ) -> ChainedRequest<T> {
    Self(
      request: request,
      decoder: decoder,
      cacheConfig: cacheConfig,
      retryConfig: RetryConfiguration(
        maxAttempts: maxAttempts,
        baseDelay: baseDelay,
        maxDelay: maxDelay
      )
    )
  }

  /// Executes the request with attached configurations.
  ///
  /// This method will:
  /// 1. Check cache if caching is configured
  /// 2. Execute request with retry logic if configured
  /// 3. Decode response body to the specified type
  ///
  /// - Parameter client: HTTP client to execute the request
  /// - Returns: DecodedResponse containing the typed value
  /// - Throws: HTTPError on network, HTTP status, or decoding failures
  public func execute(on client: any HTTPClient) async throws -> DecodedResponse<T> {
    // Execute with retry logic if configured
    let response: HTTPResponse
    if let retryConfig = retryConfig {
      response = try await executeWithRetry(
        client: client,
        maxAttempts: retryConfig.maxAttempts,
        baseDelay: retryConfig.baseDelay,
        maxDelay: retryConfig.maxDelay
      )
    } else {
      response = try await client.execute(request)
    }

    return try decodeResponse(response)
  }

  // MARK: - Private Helpers

  // swiftlint:disable:next cyclomatic_complexity
  private func executeWithRetry(
    client: any HTTPClient,
    maxAttempts: RetryAttemptCount,
    baseDelay: RetryDelay,
    maxDelay: RetryDelay
  ) async throws -> HTTPResponse {
    var lastError: Error?

    for rawAttempt in 0..<maxAttempts.rawValue {
      let attempt = RetryAttemptCount(rawAttempt)
      do {
        return try await client.execute(request)
      } catch let error as HTTPError {
        lastError = error

        // Check if error is retryable
        guard shouldRetry(error: error).rawValue else {
          throw error
        }

        // Don't delay after last attempt
        if rawAttempt < maxAttempts.rawValue - 1 {
          let delay = calculateDelay(
            attempt: attempt,
            baseDelay: baseDelay,
            maxDelay: maxDelay
          )
          try await Task.sleep(nanoseconds: UInt64(delay.rawValue * 1_000_000_000))
        }
      } catch {
        throw error
      }
    }

    throw lastError
      ?? HTTPError(
        category: .network(.serverUnreachable),
        request: request
      )
  }

  private func shouldRetry(error: HTTPError) -> RetryDecision {
    switch error.category {
    case .http(let status):
      // Retry server errors and specific client errors
      return RetryDecision(
        status.rawValue >= 500 || status.rawValue == 408 || status.rawValue == 429
      )
    case .network:
      return true
    default:
      return false
    }
  }

  private func calculateDelay(
    attempt: RetryAttemptCount,
    baseDelay: RetryDelay,
    maxDelay: RetryDelay
  ) -> RetryDelay {
    let exponentialDelay = baseDelay.rawValue * pow(2.0, Double(attempt.rawValue))
    let cappedDelay = min(exponentialDelay, maxDelay.rawValue)
    let jitter = Double.random(in: 0...(cappedDelay * 0.1))
    return RetryDelay(min(cappedDelay + jitter, maxDelay.rawValue))
  }

  private func decodeResponse(_ response: HTTPResponse) throws -> DecodedResponse<T> {
    guard let data = response.body, !data.isEmpty else {
      throw HTTPError(
        category: .decoding("Empty response body"),
        request: response.request
      )
    }

    do {
      let value = try decoder.decode(T.self, from: data.rawValue)
      return DecodedResponse(response: response, value: value)
    } catch let error as DecodingError {
      throw HTTPError(
        category: .decoding("Failed to decode \(T.self): \(error.localizedDescription)"),
        request: response.request
      )
    }
  }
}
