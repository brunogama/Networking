import NetworkingCore

extension HeaderSecurityMiddleware {
  /// Header validation limits and optional filtering policy.
  public struct Configuration: Sendable {
    /// Enforces the ASCII HTTP field-name grammar.
    public let validateHeaderNames: HeaderNameValidationFlag
    /// Checks values for excessive length, control characters, and injection patterns.
    public let validateHeaderValues: HeaderValueValidationFlag
    /// Removes disallowed value characters and excludes headers rejected by custom validation.
    public let sanitizeHeaders: HeaderSanitizationFlag
    /// Maximum number of characters in one header value.
    public let maxHeaderValueLength: HeaderValueLengthLimit
    /// Maximum number of headers in a request.
    public let maxHeaderCount: HeaderCountLimit
    /// Excludes configured proxy and forwarding headers.
    public let removeDangerousHeaders: DangerousHeaderRemovalFlag
    /// Lowercase field names to exclude when removal is enabled.
    public let dangerousHeaders: Set<DangerousHeaderName>
    /// Additional filtering evaluated after built-in validation.
    public let customValidator:
      (@Sendable (HTTPHeaderName, HTTPHeaderValue) -> HeaderValidationDecision)?

    /// Creates the validation policy; invalid header names are never repaired.
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

    /// Proxy and forwarding headers commonly owned by infrastructure.
    public static let defaultDangerousHeaders: Set<DangerousHeaderName> = [
      DangerousHeaderName("x-forwarded-for"),
      DangerousHeaderName("x-real-ip"),
      DangerousHeaderName("x-forwarded-host"),
      DangerousHeaderName("x-forwarded-proto"),
      DangerousHeaderName("proxy-authorization"),
      DangerousHeaderName("x-cluster-client-ip"),
    ]

    /// A reduced header count and value-length limit.
    public static let strict = Self(
      validateHeaderNames: true,
      validateHeaderValues: true,
      sanitizeHeaders: true,
      maxHeaderValueLength: 2048,
      maxHeaderCount: 30,
      removeDangerousHeaders: true
    )

    /// Higher size limits while retaining name and value validation.
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
