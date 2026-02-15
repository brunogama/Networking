import Foundation

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
  public var headers: [String: String] { response.headers }
  public var requestURL: URL { response.request.url }

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
  public func cacheable(ttl: TimeInterval = 300) -> CacheableResponse<T> {
    CacheableResponse(decoded: self, ttl: ttl)
  }

  /// Marks this response as retryable with specified max attempts.
  /// - Parameter maxAttempts: Maximum retry attempts (default: 3)
  /// - Returns: RetryableResponse wrapping this decoded response
  public func retryable(maxAttempts: Int = 3) -> RetryableResponse<T> {
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
  public let ttl: TimeInterval

  // Pass-through accessors
  public var value: T { decoded.value }
  public var response: HTTPResponse { decoded.response }
  public var status: HTTPStatus { decoded.status }
  public var headers: [String: String] { decoded.headers }

  public init(decoded: DecodedResponse<T>, ttl: TimeInterval) {
    self.decoded = decoded
    self.ttl = ttl
  }

  /// Chain to add retry configuration
  public func retryable(maxAttempts: Int = 3) -> RetryableCacheableResponse<T> {
    RetryableCacheableResponse(cacheable: self, maxAttempts: maxAttempts)
  }
}

// MARK: - Retryable Response

/// A decoded response with retry configuration attached.
public struct RetryableResponse<T: Sendable>: Sendable {
  public let decoded: DecodedResponse<T>
  public let maxAttempts: Int

  // Pass-through accessors
  public var value: T { decoded.value }
  public var response: HTTPResponse { decoded.response }
  public var status: HTTPStatus { decoded.status }
  public var headers: [String: String] { decoded.headers }

  public init(decoded: DecodedResponse<T>, maxAttempts: Int) {
    self.decoded = decoded
    self.maxAttempts = maxAttempts
  }

  /// Chain to add caching configuration
  public func cacheable(ttl: TimeInterval = 300) -> RetryableCacheableResponse<T> {
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
  public let maxAttempts: Int

  // Pass-through accessors
  public var value: T { cacheable.value }
  public var response: HTTPResponse { cacheable.response }
  public var status: HTTPStatus { cacheable.status }
  public var headers: [String: String] { cacheable.headers }
  public var ttl: TimeInterval { cacheable.ttl }

  public init(cacheable: CacheableResponse<T>, maxAttempts: Int) {
    self.cacheable = cacheable
    self.maxAttempts = maxAttempts
  }
}
