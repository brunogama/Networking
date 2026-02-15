import Foundation

// MARK: - HTTPResponse Fluent Extensions

extension HTTPResponse {
  /// Decodes the response body to the specified type.
  ///
  /// This is the entry point for fluent response processing chains.
  /// The decoded response preserves access to the original HTTP metadata.
  ///
  /// ```swift
  /// let user = try await client.execute(request)
  ///   .decode(User.self)
  ///   .cacheable(ttl: 300)
  ///   .retryable(maxAttempts: 3)
  ///   .value
  /// ```
  ///
  /// - Parameters:
  ///   - type: The Decodable type to decode the body as
  ///   - decoder: JSONDecoder to use (default: standard JSONDecoder)
  /// - Returns: DecodedResponse wrapping the decoded value and original response
  /// - Throws: HTTPError.decoding if body is empty or decoding fails
  public func decode<T: Decodable & Sendable>(
    _ type: T.Type,
    using decoder: JSONDecoder = JSONDecoder()
  ) throws -> DecodedResponse<T> {
    guard let body = body else {
      throw HTTPError(
        category: .decoding("Response body is empty"),
        request: request,
        response: self
      )
    }

    do {
      let value = try decoder.decode(type, from: body)
      return DecodedResponse(response: self, value: value)
    } catch {
      throw HTTPError(
        category: .decoding("Failed to decode \(T.self): \(error.localizedDescription)"),
        request: request,
        response: self,
        underlyingError: error
      )
    }
  }

  /// Decodes the response body to the specified type, returning nil on failure.
  ///
  /// - Parameters:
  ///   - type: The Decodable type to decode the body as
  ///   - decoder: JSONDecoder to use (default: standard JSONDecoder)
  /// - Returns: DecodedResponse if successful, nil if decoding fails
  public func decodeIfPresent<T: Decodable & Sendable>(
    _ type: T.Type,
    using decoder: JSONDecoder = JSONDecoder()
  ) -> DecodedResponse<T>? {
    try? decode(type, using: decoder)
  }
}
