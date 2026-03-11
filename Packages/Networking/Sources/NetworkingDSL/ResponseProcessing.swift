import Foundation
import NetworkingCore

// MARK: - Response Processing Protocol

/// Protocol for response processing operations with method chaining support
public protocol ResponseProcessor: Sendable {
  associatedtype Input
  associatedtype Output

  func process(_ input: Input) throws -> Output
}

// MARK: - Response Chain Types

/// A chainable response processing type that enables method chaining
public struct ResponseChain<T: Sendable>: Sendable {
  public let response: HTTPResponse
  public let value: T
}

// MARK: - Validation Types

/// Validation result for response processing
public enum ValidationResult: Sendable {
  case success
  case failure(HTTPError)

  public var isValid: ValidationFlag {
    switch self {
    case .success: return ValidationFlag(rawValue: true)
    case .failure: return ValidationFlag(rawValue: false)
    }
  }
}

/// Protocol for response validators
public protocol ResponseValidator: Sendable {
  func validate(_ response: HTTPResponse) -> ValidationResult
}

// MARK: - Status Code Validator

public struct StatusValidator: ResponseValidator {
  private let validStatuses: Set<HTTPStatusCode>

  public init(validStatuses: Set<HTTPStatusCode>) {
    self.validStatuses = validStatuses
  }

  public static let successStatus = Self(
    validStatuses: Set((200..<300).map { HTTPStatusCode(rawValue: $0) })
  )
  public static let anyStatus = Self(
    validStatuses: Set((100..<600).map { HTTPStatusCode(rawValue: $0) })
  )

  public func validate(_ response: HTTPResponse) -> ValidationResult {
    if validStatuses.contains(response.status.rawValue) {
      return .success
    } else {
      return .failure(
        HTTPError.http(status: response.status, request: response.request, response: response)
      )
    }
  }
}

// MARK: - Content Type Validator

public struct ContentTypeValidator: ResponseValidator {
  private let expectedContentTypes: Set<HTTPMediaType>

  public init(_ contentTypes: HTTPMediaType...) {
    self.expectedContentTypes = Set(contentTypes.map { HTTPMediaType($0.lowercased()) })
  }

  public init(_ contentTypes: Set<HTTPMediaType>) {
    self.expectedContentTypes = Set(contentTypes.map { HTTPMediaType($0.lowercased()) })
  }

  package init(_ contentTypes: String...) {
    self.expectedContentTypes = Set(contentTypes.map { HTTPMediaType($0.lowercased()) })
  }

  public static func json() -> Self {
    Self("application/json")
  }

  public static func xml() -> Self {
    Self("application/xml", "text/xml")
  }

  public static func plainText() -> Self {
    Self("text/plain")
  }

  public func validate(_ response: HTTPResponse) -> ValidationResult {
    guard let contentType = response.headers["Content-Type"]?.lowercased() else {
      return .failure(
        HTTPError(
          category: .configuration(HTTPErrorDetail(rawValue: "Missing Content-Type header")),
          request: response.request,
          response: response
        )
      )
    }

    let actualContentType =
      contentType.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespaces)
      ?? contentType

    if expectedContentTypes.contains(HTTPMediaType(actualContentType)) {
      return .success
    } else {
      return .failure(
        HTTPError(
          category: .configuration(
            HTTPErrorDetail(
              rawValue:
                "Expected Content-Type \(expectedContentTypes.map { $0.rawValue }), got \(actualContentType)"
            )
          ),
          request: response.request,
          response: response
        )
      )
    }
  }
}

// MARK: - Response Transformation

/// Protocol for response transformers
public protocol ResponseTransformer<Input, Output>: Sendable {
  associatedtype Input
  associatedtype Output

  func transform(_ input: Input) throws -> Output
}

// MARK: - JSON Decoder Transformer

public struct JSONDecoderTransformer<T: Decodable & Sendable>: ResponseTransformer {
  public typealias Input = HTTPBody
  public typealias Output = T

  private let decoder: JSONDecoder
  private let type: T.Type

  public init(_ type: T.Type, decoder: JSONDecoder = JSONDecoder()) {
    self.type = type
    self.decoder = decoder
  }

  public func transform(_ input: HTTPBody) throws -> T {
    do {
      return try decoder.decode(type, from: input)
    } catch {
      throw HTTPError(
        category: .decoding(
          HTTPErrorDetail(rawValue: "Failed to decode \(type): \(error.localizedDescription)")
        ),
        underlyingError: error
      )
    }
  }
}

// MARK: - String Transformer

public struct StringTransformer: ResponseTransformer {
  public typealias Input = HTTPBody
  public typealias Output = HTTPResponseText

  private let encoding: HTTPTextEncoding

  public init(encoding: HTTPTextEncoding = .utf8) {
    self.encoding = encoding
  }

  public func transform(_ input: HTTPBody) throws -> HTTPResponseText {
    guard let resolvedEncoding = encoding.foundationEncoding else {
      throw HTTPError(
        category: .configuration(
          HTTPErrorDetail(rawValue: "Unsupported text encoding: \(encoding)")
        )
      )
    }

    guard let string = String(data: input, encoding: resolvedEncoding) else {
      throw HTTPError(
        category: .decoding(
          HTTPErrorDetail(rawValue: "Failed to convert data to string using \(encoding) encoding")
        )
      )
    }
    return HTTPResponseText(string)
  }
}

// MARK: - Response Cache Duration

public struct ResponseCacheDuration: Sendable {
  public let seconds: NetworkingCore.RequestTimeout

  public init(seconds: NetworkingCore.RequestTimeout) {
    self.seconds = seconds
  }

  package init(seconds: TimeInterval) {
    self.seconds = NetworkingCore.RequestTimeout(seconds)
  }

  public static func seconds(_ value: NetworkingCore.RequestTimeout) -> Self {
    Self(seconds: value)
  }

  public static func minutes(_ value: NetworkingCore.RequestTimeout) -> Self {
    Self(seconds: NetworkingCore.RequestTimeout(value.rawValue * 60))
  }

  public static func hours(_ value: NetworkingCore.RequestTimeout) -> Self {
    Self(seconds: NetworkingCore.RequestTimeout(value.rawValue * 3600))
  }

  public static func days(_ value: NetworkingCore.RequestTimeout) -> Self {
    Self(seconds: NetworkingCore.RequestTimeout(value.rawValue * 86_400))
  }
}

// MARK: - Specialized Response Types

// ValidatedResponse is now defined in ValidatedResponse.swift

// DecodableResponse is now defined in ValidatedResponse.swift with enhanced features

/// A cached response with cache metadata
public struct ProcessedCachedResponse<T: Sendable>: Sendable {
  public let response: HTTPResponse
  public let value: T
  public let cacheExpiry: Date

  internal init(response: HTTPResponse, value: T, cacheExpiry: Date) {
    self.response = response
    self.value = value
    self.cacheExpiry = cacheExpiry
  }

  public var isCacheValid: CacheValidityFlag {
    CacheValidityFlag(Date() < cacheExpiry)
  }
}

/// A transformed response with data transformation
public struct TransformedResponse<T: Sendable>: Sendable {
  public let response: HTTPResponse
  public let value: T
}
