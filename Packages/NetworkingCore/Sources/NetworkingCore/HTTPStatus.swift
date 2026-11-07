/// A structure representing an HTTP status code.
///
/// Using a struct instead of an enum provides flexibility for custom status codes.
public struct HTTPStatus: Sendable, Hashable {
  // MARK: - 1xx Informational

  /// HTTP 100 Continue.
  public static let `continue` = Self(rawValue: 100)
  /// HTTP 101 Switching Protocols.
  public static let switchingProtocols = Self(rawValue: 101)

  // MARK: - 2xx Success

  /// HTTP 200 OK.
  public static let ok = Self(rawValue: 200)
  /// HTTP 201 Created.
  public static let created = Self(rawValue: 201)
  /// HTTP 202 Accepted.
  public static let accepted = Self(rawValue: 202)
  /// HTTP 203 Non-Authoritative Information.
  public static let nonAuthoritativeInformation = Self(rawValue: 203)
  /// HTTP 204 No Content.
  public static let noContent = Self(rawValue: 204)
  /// HTTP 205 Reset Content.
  public static let resetContent = Self(rawValue: 205)
  /// HTTP 206 Partial Content.
  public static let partialContent = Self(rawValue: 206)

  // MARK: - 3xx Redirection

  /// HTTP 300 Multiple Choices.
  public static let multipleChoices = Self(rawValue: 300)
  /// HTTP 301 Moved Permanently.
  public static let movedPermanently = Self(rawValue: 301)
  /// HTTP 302 Found.
  public static let found = Self(rawValue: 302)
  /// HTTP 303 See Other.
  public static let seeOther = Self(rawValue: 303)
  /// HTTP 304 Not Modified.
  public static let notModified = Self(rawValue: 304)
  /// HTTP 305 Use Proxy.
  public static let useProxy = Self(rawValue: 305)
  /// HTTP 307 Temporary Redirect.
  public static let temporaryRedirect = Self(rawValue: 307)
  /// HTTP 308 Permanent Redirect.
  public static let permanentRedirect = Self(rawValue: 308)

  // MARK: - 4xx Client Error

  /// HTTP 400 Bad Request.
  public static let badRequest = Self(rawValue: 400)
  /// HTTP 401 Unauthorized.
  public static let unauthorized = Self(rawValue: 401)
  /// HTTP 402 Payment Required.
  public static let paymentRequired = Self(rawValue: 402)
  /// HTTP 403 Forbidden.
  public static let forbidden = Self(rawValue: 403)
  /// HTTP 404 Not Found.
  public static let notFound = Self(rawValue: 404)
  /// HTTP 405 Method Not Allowed.
  public static let methodNotAllowed = Self(rawValue: 405)
  /// HTTP 406 Not Acceptable.
  public static let notAcceptable = Self(rawValue: 406)
  /// HTTP 407 Proxy Authentication Required.
  public static let proxyAuthenticationRequired = Self(rawValue: 407)
  /// HTTP 408 Request Timeout.
  public static let requestTimeout = Self(rawValue: 408)
  /// HTTP 409 Conflict.
  public static let conflict = Self(rawValue: 409)
  /// HTTP 410 Gone.
  public static let gone = Self(rawValue: 410)
  /// HTTP 411 Length Required.
  public static let lengthRequired = Self(rawValue: 411)
  /// HTTP 412 Precondition Failed.
  public static let preconditionFailed = Self(rawValue: 412)
  /// HTTP 413 Payload Too Large.
  public static let payloadTooLarge = Self(rawValue: 413)
  /// HTTP 414 URI Too Long.
  public static let uriTooLong = Self(rawValue: 414)
  /// HTTP 415 Unsupported Media Type.
  public static let unsupportedMediaType = Self(rawValue: 415)
  /// HTTP 416 Range Not Satisfiable.
  public static let rangeNotSatisfiable = Self(rawValue: 416)
  /// HTTP 417 Expectation Failed.
  public static let expectationFailed = Self(rawValue: 417)
  /// HTTP 418 I'm a Teapot.
  public static let imATeapot = Self(rawValue: 418)
  /// HTTP 422 Unprocessable Entity.
  public static let unprocessableEntity = Self(rawValue: 422)
  /// HTTP 429 Too Many Requests.
  public static let tooManyRequests = Self(rawValue: 429)

  // MARK: - 5xx Server Error

  /// HTTP 500 Internal Server Error.
  public static let internalServerError = Self(rawValue: 500)
  /// HTTP 501 Not Implemented.
  public static let notImplemented = Self(rawValue: 501)
  /// HTTP 502 Bad Gateway.
  public static let badGateway = Self(rawValue: 502)
  /// HTTP 503 Service Unavailable.
  public static let serviceUnavailable = Self(rawValue: 503)
  /// HTTP 504 Gateway Timeout.
  public static let gatewayTimeout = Self(rawValue: 504)
  /// HTTP 505 HTTP Version Not Supported.
  public static let httpVersionNotSupported = Self(rawValue: 505)

  // MARK: - Properties

  /// The numeric status code.
  public let rawValue: HTTPStatusCode
  // MARK: - Initialization

  /// Creates a status from its numeric code, including custom codes.
  public init(_ rawValue: HTTPStatusCode) {
    self.rawValue = rawValue
  }

  /// Creates a status from a labeled numeric code.
  public init(rawValue: HTTPStatusCode) {
    self.init(rawValue)
  }

  package init(rawValue: Int) {
    self.init(rawValue: HTTPStatusCode(rawValue))
  }

  // MARK: - Computed Properties

  /// Returns true if the status code is in the 1xx range.
  public var isInformational: HTTPStatusInformationalFlag {
    HTTPStatusInformationalFlag(100..<200 ~= rawValue)
  }

  /// Returns true if the status code is in the 2xx range.
  public var isSuccess: HTTPStatusSuccessFlag {
    HTTPStatusSuccessFlag(200..<300 ~= rawValue)
  }

  /// Returns true if the status code is in the 3xx range.
  public var isRedirection: HTTPStatusRedirectionFlag {
    HTTPStatusRedirectionFlag(300..<400 ~= rawValue)
  }

  /// Returns true if the status code is in the 4xx range.
  public var isClientError: HTTPStatusClientErrorFlag {
    HTTPStatusClientErrorFlag(400..<500 ~= rawValue)
  }

  /// Returns true if the status code is in the 5xx range.
  public var isServerError: HTTPStatusServerErrorFlag {
    HTTPStatusServerErrorFlag(500..<600 ~= rawValue)
  }

}
