import Foundation
import NetworkingCore

extension HTTPResponse {
  public func chain() -> ResponseChain<HTTPResponse> {
    ResponseChain(response: self, value: self)
  }

  public func validate(_ validator: any ResponseValidator) throws -> ResponseChain<HTTPResponse> {
    let result = validator.validate(self)
    switch result {
    case .success:
      return chain()
    case .failure(let error):
      throw error
    }
  }

  public func validateSuccess() throws -> ResponseChain<HTTPResponse> {
    try validate(StatusValidator.successStatus)
  }

  public func cache(for duration: ResponseCacheDuration) -> ProcessedCachedResponse<HTTPResponse> {
    let expiry = Date().addingTimeInterval(duration.seconds.rawValue)
    return ProcessedCachedResponse(response: self, value: self, cacheExpiry: expiry)
  }

  public func transform<T: Sendable>(
    _ transformer: some ResponseTransformer<HTTPResponse, T>
  ) throws -> TransformedResponse<T> {
    let transformedValue = try transformer.transform(self)
    return TransformedResponse(response: self, value: transformedValue)
  }

  @available(*, deprecated, message: "Use chain().validate(.successStatus) instead")
  public func validateStatus() throws {
    if status.isClientError.rawValue || status.isServerError.rawValue {
      throw HTTPError.http(status: status, request: request, response: self)
    }
  }

  @available(*, deprecated, message: "Use chain().decode(_:using:) instead")
  public func decode<T: Decodable>(
    _ type: T.Type,
    using decoder: JSONDecoder = JSONDecoder()
  ) throws -> T {
    guard let body = body else {
      throw HTTPError(
        category: .decoding(HTTPErrorDetail(rawValue: "Response body is empty")),
        request: request,
        response: self
      )
    }

    do {
      return try decoder.decode(type, from: body)
    } catch {
      throw HTTPError(
        category: .decoding(
          HTTPErrorDetail(rawValue: "Failed to decode \(type): \(error.localizedDescription)")
        ),
        request: request,
        response: self,
        underlyingError: error
      )
    }
  }

  @available(*, deprecated, message: "Use chain().transform(StringTransformer()) instead")
  public func bodyAsString(encoding: HTTPTextEncoding = .utf8) -> HTTPResponseText? {
    guard let body = body else { return nil }
    guard let resolvedEncoding = encoding.foundationEncoding else {
      return nil
    }
    return String(data: body, encoding: resolvedEncoding).map { HTTPResponseText($0) }
  }
}

extension ResponseChain {
  public func validate(_ validator: any ResponseValidator) throws -> ResponseChain<T> {
    let result = validator.validate(response)
    switch result {
    case .success:
      return self
    case .failure(let error):
      throw error
    }
  }

  public func validateSuccess() throws -> ValidatedResponse<T> {
    let result = StatusValidator.successStatus.validate(response)
    switch result {
    case .success:
      return ValidatedResponse(response: response, value: value)
    case .failure(let error):
      throw error
    }
  }
}

extension ResponseChain where T == HTTPResponse {
  public func decode<U>(
    _ transformer: some ResponseTransformer<HTTPBody, U>
  ) throws -> ResponseChain<U> {
    guard let body = response.body else {
      throw HTTPError(
        category: .decoding(HTTPErrorDetail(rawValue: "Response body is empty")),
        request: response.request,
        response: response
      )
    }

    let decodedValue = try transformer.transform(body)
    return ResponseChain<U>(response: response, value: decodedValue)
  }

  public func asString(
    encoding: HTTPTextEncoding = .utf8
  ) throws -> TransformedResponse<HTTPResponseText> {
    guard let body = response.body else {
      throw HTTPError(
        category: .decoding(HTTPErrorDetail(rawValue: "Response body is empty")),
        request: response.request,
        response: response
      )
    }

    let transformer = StringTransformer(encoding: encoding)
    let stringValue = try transformer.transform(body)
    return TransformedResponse(response: response, value: stringValue)
  }
}

extension ResponseChain {
  public func transform<U>(
    _ transformer: some ResponseTransformer<T, U>
  ) throws -> ResponseChain<U> {
    let transformedValue = try transformer.transform(value)
    return ResponseChain<U>(response: response, value: transformedValue)
  }

  public func cache(for duration: ResponseCacheDuration) -> ProcessedCachedResponse<T> {
    let expiry = Date().addingTimeInterval(duration.seconds.rawValue)
    return ProcessedCachedResponse(response: response, value: value, cacheExpiry: expiry)
  }

  public func map<U>(_ transform: (T) throws -> U) throws -> ResponseChain<U> {
    let transformedValue = try transform(value)
    return ResponseChain<U>(response: response, value: transformedValue)
  }

  public func recover(_ recovery: (HTTPError) throws -> T) throws -> ResponseChain<T> {
    self
  }

  public func extractValue() -> T {
    value
  }

  public func result() -> (response: HTTPResponse, value: T) {
    (response: response, value: value)
  }
}

extension ResponseChain {
  public static func withRecovery<U>(
    _ operation: () throws -> ResponseChain<U>,
    recovery: (HTTPError) throws -> ResponseChain<U>
  ) throws -> ResponseChain<U> {
    do {
      return try operation()
    } catch let error as HTTPError {
      return try recovery(error)
    }
  }
}

extension ResponseValidator where Self == StatusValidator {
  public static var successStatus: StatusValidator {
    StatusValidator.successStatus
  }

  public static var anyStatus: StatusValidator {
    StatusValidator.anyStatus
  }

  public static func status(_ codes: HTTPStatusCode...) -> StatusValidator {
    StatusValidator(validStatuses: Set(codes))
  }
}

extension ResponseValidator where Self == ContentTypeValidator {
  public static func contentType(_ type: HTTPMediaType) -> ContentTypeValidator {
    ContentTypeValidator(type)
  }

  public static var json: ContentTypeValidator {
    ContentTypeValidator.json()
  }

  public static var xml: ContentTypeValidator {
    ContentTypeValidator.xml()
  }

  public static var plainText: ContentTypeValidator {
    ContentTypeValidator.plainText()
  }
}
