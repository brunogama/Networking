import NetworkingCore

extension HeaderSecurityMiddleware {
  public struct Configuration: Sendable {
    public let validateHeaderNames: HeaderNameValidationFlag
    public let validateHeaderValues: HeaderValueValidationFlag
    public let sanitizeHeaders: HeaderSanitizationFlag
    public let maxHeaderValueLength: HeaderValueLengthLimit
    public let maxHeaderCount: HeaderCountLimit
    public let removeDangerousHeaders: DangerousHeaderRemovalFlag
    public let dangerousHeaders: Set<DangerousHeaderName>
    public let customValidator:
      (@Sendable (HTTPHeaderName, HTTPHeaderValue) -> HeaderValidationDecision)?

    public init(
      validateHeaderNames: HeaderNameValidationFlag = true,
      validateHeaderValues: HeaderValueValidationFlag = true,
      sanitizeHeaders: HeaderSanitizationFlag = true,
      maxHeaderValueLength: HeaderValueLengthLimit = 4096,
      maxHeaderCount: HeaderCountLimit = 50,
      removeDangerousHeaders: DangerousHeaderRemovalFlag = true,
      dangerousHeaders: Set<DangerousHeaderName> = Self.defaultDangerousHeaders,
      customValidator: (@Sendable (HTTPHeaderName, HTTPHeaderValue) -> HeaderValidationDecision)? =
        nil
    ) {
      self.validateHeaderNames = validateHeaderNames
      self.validateHeaderValues = validateHeaderValues
      self.sanitizeHeaders = sanitizeHeaders
      self.maxHeaderValueLength = maxHeaderValueLength
      self.maxHeaderCount = maxHeaderCount
      self.removeDangerousHeaders = removeDangerousHeaders
      self.dangerousHeaders = dangerousHeaders
      self.customValidator = customValidator
    }

    public static let defaultDangerousHeaders: Set<DangerousHeaderName> = [
      DangerousHeaderName("x-forwarded-for"),
      DangerousHeaderName("x-real-ip"),
      DangerousHeaderName("x-forwarded-host"),
      DangerousHeaderName("x-forwarded-proto"),
      DangerousHeaderName("proxy-authorization"),
      DangerousHeaderName("x-cluster-client-ip"),
    ]

    public static let strict = Self(
      validateHeaderNames: true,
      validateHeaderValues: true,
      sanitizeHeaders: true,
      maxHeaderValueLength: 2048,
      maxHeaderCount: 30,
      removeDangerousHeaders: true
    )

    public static let permissive = Self(
      validateHeaderNames: true,
      validateHeaderValues: true,
      sanitizeHeaders: true,
      maxHeaderValueLength: 8192,
      maxHeaderCount: 100,
      removeDangerousHeaders: false
    )
  }
}

extension HeaderSecurityMiddleware.Configuration {
  /// Configuration for API clients that need to be extra secure.
  public static let api = Self(
    validateHeaderNames: true,
    validateHeaderValues: true,
    sanitizeHeaders: false,
    maxHeaderValueLength: 1024,
    maxHeaderCount: 20,
    removeDangerousHeaders: true
  )

  /// Configuration for web clients that need more flexibility.
  public static let web = Self(
    validateHeaderNames: true,
    validateHeaderValues: true,
    sanitizeHeaders: true,
    maxHeaderValueLength: 2048,
    maxHeaderCount: 40,
    removeDangerousHeaders: false
  )
}

extension HeaderSecurityMiddleware: ConfigurationComponent {
  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    configuration.requestMiddlewares.append(self)
  }
}
