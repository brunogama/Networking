import Foundation

/// A structure representing an HTTP status code.
/// Using a struct instead of an enum provides flexibility for custom status codes.
public struct HTTPStatus: Sendable, Hashable {
  // MARK: - 1xx Informational

  public static let `continue` = Self(rawValue: 100)
  public static let switchingProtocols = Self(rawValue: 101)

  // MARK: - 2xx Success

  public static let ok = Self(rawValue: 200)
  public static let created = Self(rawValue: 201)
  public static let accepted = Self(rawValue: 202)
  public static let nonAuthoritativeInformation = Self(rawValue: 203)
  public static let noContent = Self(rawValue: 204)
  public static let resetContent = Self(rawValue: 205)
  public static let partialContent = Self(rawValue: 206)

  // MARK: - 3xx Redirection

  public static let multipleChoices = Self(rawValue: 300)
  public static let movedPermanently = Self(rawValue: 301)
  public static let found = Self(rawValue: 302)
  public static let seeOther = Self(rawValue: 303)
  public static let notModified = Self(rawValue: 304)
  public static let useProxy = Self(rawValue: 305)
  public static let temporaryRedirect = Self(rawValue: 307)
  public static let permanentRedirect = Self(rawValue: 308)

  // MARK: - 4xx Client Error

  public static let badRequest = Self(rawValue: 400)
  public static let unauthorized = Self(rawValue: 401)
  public static let paymentRequired = Self(rawValue: 402)
  public static let forbidden = Self(rawValue: 403)
  public static let notFound = Self(rawValue: 404)
  public static let methodNotAllowed = Self(rawValue: 405)
  public static let notAcceptable = Self(rawValue: 406)
  public static let proxyAuthenticationRequired = Self(rawValue: 407)
  public static let requestTimeout = Self(rawValue: 408)
  public static let conflict = Self(rawValue: 409)
  public static let gone = Self(rawValue: 410)
  public static let lengthRequired = Self(rawValue: 411)
  public static let preconditionFailed = Self(rawValue: 412)
  public static let payloadTooLarge = Self(rawValue: 413)
  public static let uriTooLong = Self(rawValue: 414)
  public static let unsupportedMediaType = Self(rawValue: 415)
  public static let rangeNotSatisfiable = Self(rawValue: 416)
  public static let expectationFailed = Self(rawValue: 417)
  public static let imATeapot = Self(rawValue: 418)
  public static let unprocessableEntity = Self(rawValue: 422)
  public static let tooManyRequests = Self(rawValue: 429)

  // MARK: - 5xx Server Error

  public static let internalServerError = Self(rawValue: 500)
  public static let notImplemented = Self(rawValue: 501)
  public static let badGateway = Self(rawValue: 502)
  public static let serviceUnavailable = Self(rawValue: 503)
  public static let gatewayTimeout = Self(rawValue: 504)
  public static let httpVersionNotSupported = Self(rawValue: 505)

  // MARK: - Properties

  public let rawValue: HTTPStatusCode
  // MARK: - Initialization

  public init(_ rawValue: HTTPStatusCode) {
    self.rawValue = rawValue
  }

  public init(rawValue: HTTPStatusCode) {
    self.init(rawValue)
  }

  package init(rawValue: Int) {
    self.init(rawValue: HTTPStatusCode(rawValue))
  }

  // MARK: - Computed Properties

  /// Returns true if the status code is in the 1xx range
  public var isInformational: HTTPStatusInformationalFlag {
    HTTPStatusInformationalFlag(100..<200 ~= rawValue)
  }

  /// Returns true if the status code is in the 2xx range
  public var isSuccess: HTTPStatusSuccessFlag {
    HTTPStatusSuccessFlag(200..<300 ~= rawValue)
  }

  /// Returns true if the status code is in the 3xx range
  public var isRedirection: HTTPStatusRedirectionFlag {
    HTTPStatusRedirectionFlag(300..<400 ~= rawValue)
  }

  /// Returns true if the status code is in the 4xx range
  public var isClientError: HTTPStatusClientErrorFlag {
    HTTPStatusClientErrorFlag(400..<500 ~= rawValue)
  }

  /// Returns true if the status code is in the 5xx range
  public var isServerError: HTTPStatusServerErrorFlag {
    HTTPStatusServerErrorFlag(500..<600 ~= rawValue)
  }

  package var codeValue: Int {
    rawValue.rawValue
  }
}
