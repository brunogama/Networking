import Foundation

// MARK: - Decodable Response Types

/// A response that has been successfully decoded from JSON with type safety
public struct DecodableResponse<T: Decodable & Sendable>: ValidatedResponseProtocol, Sendable {
  public typealias ValueType = T

  public let response: HTTPResponse
  public let value: T
  public let validationResults: [ValidationResult]
  public let decodingMetadata: DecodingMetadata

  public struct DecodingMetadata: Sendable {
    public let decoder: String  // Name/type of decoder used
    public let decodedAt: Date
    public let originalDataSize: Int
    public let decodingDuration: TimeInterval?

    public init(
      decoder: String = "JSONDecoder",
      decodedAt: Date = Date(),
      originalDataSize: Int,
      decodingDuration: TimeInterval? = nil
    ) {
      self.decoder = decoder
      self.decodedAt = decodedAt
      self.originalDataSize = originalDataSize
      self.decodingDuration = decodingDuration
    }
  }

  public init(
    response: HTTPResponse,
    value: T,
    decodingMetadata: DecodingMetadata,
    validationResults: [ValidationResult] = [.success]
  ) {
    self.response = response
    self.value = value
    self.decodingMetadata = decodingMetadata
    self.validationResults = validationResults
  }

  /// Creates a DecodableResponse by decoding JSON from the response body
  public static func decode(
    from response: HTTPResponse,
    using decoder: JSONDecoder = JSONDecoder()
  ) throws -> DecodableResponse<T> {
    guard let body = response.body else {
      throw HTTPError(
        category: .decoding("Response body is empty"),
        request: response.request,
        response: response
      )
    }

    let startTime = CFAbsoluteTimeGetCurrent()

    do {
      let decodedValue = try decoder.decode(T.self, from: body)
      let endTime = CFAbsoluteTimeGetCurrent()
      let decodingDuration = endTime - startTime

      let metadata = DecodingMetadata(
        decoder: "JSONDecoder",
        decodedAt: Date(),
        originalDataSize: body.count,
        decodingDuration: decodingDuration
      )

      return Self(
        response: response,
        value: decodedValue,
        decodingMetadata: metadata
      )
    } catch {
      throw HTTPError(
        category: .decoding("Failed to decode \(T.self): \(error.localizedDescription)"),
        request: response.request,
        response: response,
        underlyingError: error
      )
    }
  }

  /// Decoding performance metrics
  public var decodingRate: Double? {
    guard let duration = decodingMetadata.decodingDuration, duration > 0 else { return nil }
    return Double(decodingMetadata.originalDataSize) / duration  // bytes per second
  }
}

/// A response that combines both caching and decoding features
public struct CachedDecodableResponse<T: Decodable & Sendable>: ValidatedResponseProtocol, Sendable
{
  public typealias ValueType = T

  public let response: HTTPResponse
  public let value: T
  public let validationResults: [ValidationResult]
  public let cacheMetadata: CacheMetadata
  public let decodingMetadata: DecodableResponse<T>.DecodingMetadata
  public let isCacheHit: Bool
  public let cacheTimestamp: Date

  public init(
    response: HTTPResponse,
    value: T,
    cacheMetadata: CacheMetadata,
    decodingMetadata: DecodableResponse<T>.DecodingMetadata,
    isCacheHit: Bool = false,
    cacheTimestamp: Date = Date(),
    validationResults: [ValidationResult] = [.success]
  ) {
    self.response = response
    self.value = value
    self.cacheMetadata = cacheMetadata
    self.decodingMetadata = decodingMetadata
    self.isCacheHit = isCacheHit
    self.cacheTimestamp = cacheTimestamp
    self.validationResults = validationResults
  }

  /// Convenience initializer from separate cached and decodable responses
  public init(
    decodable: DecodableResponse<T>,
    cacheMetadata: CacheMetadata,
    isCacheHit: Bool = false,
    cacheTimestamp: Date = Date()
  ) {
    self.response = decodable.response
    self.value = decodable.value
    self.validationResults = decodable.validationResults
    self.cacheMetadata = cacheMetadata
    self.decodingMetadata = decodable.decodingMetadata
    self.isCacheHit = isCacheHit
    self.cacheTimestamp = cacheTimestamp
  }

  /// Cache age since the response was first cached
  public var cacheAge: TimeInterval {
    Date().timeIntervalSince(cacheTimestamp)
  }

  /// Whether the cached response is still fresh (within TTL)
  public var isFresh: Bool {
    guard let ttl = cacheMetadata.ttl else { return true }
    return cacheAge < ttl
  }

  /// Decoding performance metrics
  public var decodingRate: Double? {
    guard let duration = decodingMetadata.decodingDuration, duration > 0 else { return nil }
    return Double(decodingMetadata.originalDataSize) / duration  // bytes per second
  }

  /// Create from a CachedResponse with decoding
  public static func decode(
    from cachedResponse: CachedResponse<HTTPResponse>,
    using decoder: JSONDecoder = JSONDecoder()
  ) throws -> CachedDecodableResponse<T> {
    let decodableResponse = try DecodableResponse<T>.decode(
      from: cachedResponse.response,
      using: decoder
    )

    return Self(
      decodable: decodableResponse,
      cacheMetadata: cachedResponse.cacheMetadata,
      isCacheHit: cachedResponse.isCacheHit,
      cacheTimestamp: cachedResponse.cacheTimestamp
    )
  }
}
