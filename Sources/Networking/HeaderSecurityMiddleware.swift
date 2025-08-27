import Foundation

/// Middleware that provides security validation and sanitization for HTTP headers.
public struct HeaderSecurityMiddleware: HTTPRequestMiddleware {
  // MARK: - Configuration

  public struct Configuration: Sendable {
    /// Whether to validate header names for injection attacks
    public let validateHeaderNames: Bool

    /// Whether to validate header values for injection attacks
    public let validateHeaderValues: Bool

    /// Whether to sanitize invalid headers by removing them
    public let sanitizeHeaders: Bool

    /// Maximum allowed header value length (prevents DoS attacks)
    public let maxHeaderValueLength: Int

    /// Maximum allowed number of headers (prevents DoS attacks)
    public let maxHeaderCount: Int

    /// Whether to remove potentially dangerous headers
    public let removeDangerousHeaders: Bool

    /// Set of header names that should be removed for security
    public let dangerousHeaders: Set<String>

    /// Custom header validation function
    public let customValidator: (@Sendable (String, String) -> Bool)?

    public init(
      validateHeaderNames: Bool = true,
      validateHeaderValues: Bool = true,
      sanitizeHeaders: Bool = true,
      maxHeaderValueLength: Int = 4096,
      maxHeaderCount: Int = 50,
      removeDangerousHeaders: Bool = true,
      dangerousHeaders: Set<String> = Self.defaultDangerousHeaders,
      customValidator: (@Sendable (String, String) -> Bool)? = nil
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

    /// Default set of potentially dangerous headers
    public static let defaultDangerousHeaders: Set<String> = [
      "x-forwarded-for",
      "x-real-ip",
      "x-forwarded-host",
      "x-forwarded-proto",
      "proxy-authorization",
      "x-cluster-client-ip",
    ]

    /// Strict security configuration
    public static let strict = Self(
      validateHeaderNames: true,
      validateHeaderValues: true,
      sanitizeHeaders: true,
      maxHeaderValueLength: 2048,
      maxHeaderCount: 30,
      removeDangerousHeaders: true
    )

    /// Permissive configuration for development
    public static let permissive = Self(
      validateHeaderNames: true,
      validateHeaderValues: true,
      sanitizeHeaders: true,
      maxHeaderValueLength: 8192,
      maxHeaderCount: 100,
      removeDangerousHeaders: false
    )
  }

  // MARK: - Properties

  private let configuration: Configuration

  // MARK: - Initialization

  public init(configuration: Configuration = Configuration()) {
    self.configuration = configuration
  }

  // MARK: - HTTPRequestMiddleware

  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    // Validate header count
    if request.headers.count > configuration.maxHeaderCount {
      throw HTTPError(
        category: .security(.headerInjection),
        request: request,
        message: "Too many headers: \(request.headers.count) > \(configuration.maxHeaderCount)"
      )
    }

    var sanitizedHeaders: [String: String] = [:]

    for (name, value) in request.headers {
      // Validate header name
      if configuration.validateHeaderNames {
        try validateHeaderName(name, for: request)
      }

      // Validate header value
      if configuration.validateHeaderValues {
        try validateHeaderValue(value, for: request)
      }

      // Check if header is dangerous and should be removed
      if configuration.removeDangerousHeaders
        && configuration.dangerousHeaders.contains(name.lowercased())
      {
        continue  // Skip dangerous header
      }

      // Apply custom validation if provided
      if let customValidator = configuration.customValidator {
        if !customValidator(name, value) {
          if configuration.sanitizeHeaders {
            continue  // Skip invalid header
          } else {
            throw HTTPError(
              category: .security(.headerInjection),
              request: request,
              message: "Header failed custom validation: \(name)"
            )
          }
        }
      }

      // Sanitize header value if needed
      let sanitizedValue = sanitizeHeaderValue(value)
      sanitizedHeaders[name] = sanitizedValue
    }

    // Create new request with sanitized headers
    return HTTPRequest(
      method: request.method,
      url: request.url,
      headers: sanitizedHeaders,
      body: request.body,
      timeout: request.timeout
    )
  }

  // MARK: - Validation Methods

  private func validateHeaderName(_ name: String, for request: HTTPRequest) throws {
    // Check for empty header name
    if name.isEmpty {
      throw HTTPError(
        category: .security(.headerInjection),
        request: request,
        message: "Empty header name"
      )
    }

    // Check for control characters and invalid characters in header name
    let invalidCharacters = CharacterSet.controlCharacters
      .union(CharacterSet.whitespacesAndNewlines)
      .union(CharacterSet(charactersIn: "()<>@,;:\\\"/[]?={}"))

    if name.rangeOfCharacter(from: invalidCharacters) != nil {
      if configuration.sanitizeHeaders {
        return  // Will be sanitized later
      } else {
        throw HTTPError(
          category: .security(.headerInjection),
          request: request,
          message: "Invalid characters in header name: \(name)"
        )
      }
    }

    // Check for header injection patterns
    if containsInjectionPattern(name) {
      throw HTTPError(
        category: .security(.headerInjection),
        request: request,
        message: "Potential header injection in name: \(name)"
      )
    }
  }

  private func validateHeaderValue(_ value: String, for request: HTTPRequest) throws {
    // Check maximum length
    if value.count > configuration.maxHeaderValueLength {
      throw HTTPError(
        category: .security(.headerInjection),
        request: request,
        message: "Header value too long: \(value.count) > \(configuration.maxHeaderValueLength)"
      )
    }

    // Check for control characters (except tab)
    let invalidCharacters = CharacterSet.controlCharacters.subtracting(
      CharacterSet(charactersIn: "\t")
    )

    if value.rangeOfCharacter(from: invalidCharacters) != nil {
      if configuration.sanitizeHeaders {
        return  // Will be sanitized later
      } else {
        throw HTTPError(
          category: .security(.headerInjection),
          request: request,
          message: "Invalid control characters in header value: \(value.prefix(50))"
        )
      }
    }

    // Check for header injection patterns
    if containsInjectionPattern(value) {
      throw HTTPError(
        category: .security(.headerInjection),
        request: request,
        message: "Potential header injection in value: \(value.prefix(50))"
      )
    }

    // Check for common injection patterns
    if containsSuspiciousPatterns(value) {
      throw HTTPError(
        category: .security(.headerInjection),
        request: request,
        message: "Suspicious patterns detected in header value"
      )
    }
  }

  private func sanitizeHeaderValue(_ value: String) -> String {
    // Remove control characters (except tab) and newlines
    let allowedCharacters = CharacterSet.controlCharacters
      .subtracting(CharacterSet(charactersIn: "\t"))
      .inverted

    let components = value.components(separatedBy: allowedCharacters.inverted)
    let sanitized = components.joined()

    // Truncate if too long
    if sanitized.count > configuration.maxHeaderValueLength {
      return String(sanitized.prefix(configuration.maxHeaderValueLength))
    }

    return sanitized
  }

  private func containsInjectionPattern(_ value: String) -> Bool {
    let injectionPatterns = [
      "\r\n",  // CRLF injection
      "\n",  // LF injection
      "\r",  // CR injection
      "%0d%0a",  // URL encoded CRLF
      "%0a",  // URL encoded LF
      "%0d",  // URL encoded CR
      "\\r\\n",  // Escaped CRLF
      "\\n",  // Escaped LF
      "\\r",  // Escaped CR
    ]

    let lowercaseValue = value.lowercased()

    for pattern in injectionPatterns {
      if lowercaseValue.contains(pattern) {
        return true
      }
    }

    return false
  }

  private func containsSuspiciousPatterns(_ value: String) -> Bool {
    let suspiciousPatterns = [
      "<script",
      "javascript:",
      "data:",
      "vbscript:",
      "onload=",
      "onerror=",
      "onclick=",
      "eval(",
      "expression(",
      "url(",
      "@import",
    ]

    let lowercaseValue = value.lowercased()

    for pattern in suspiciousPatterns {
      if lowercaseValue.contains(pattern) {
        return true
      }
    }

    return false
  }
}

// MARK: - HTTPError Security Extensions

extension HTTPError {
  public enum SecurityError: Sendable {
    case headerInjection
    case maliciousContent
    case suspiciousActivity
    case rateLimitExceeded
  }
}

extension HTTPError.Category {
  public static func security(_ error: HTTPError.SecurityError) -> Self {
    switch error {
    case .headerInjection:
      return .custom("Security", "Header injection attack detected")

    case .maliciousContent:
      return .custom("Security", "Malicious content detected")

    case .suspiciousActivity:
      return .custom("Security", "Suspicious activity detected")

    case .rateLimitExceeded:
      return .custom("Security", "Rate limit exceeded")
    }
  }
}

// MARK: - Convenience Extensions

extension HeaderSecurityMiddleware.Configuration {
  /// Configuration for API clients that need to be extra secure
  public static let api = Self(
    validateHeaderNames: true,
    validateHeaderValues: true,
    sanitizeHeaders: false,  // Fail fast for APIs
    maxHeaderValueLength: 1024,
    maxHeaderCount: 20,
    removeDangerousHeaders: true
  )

  /// Configuration for web clients that need more flexibility
  public static let web = Self(
    validateHeaderNames: true,
    validateHeaderValues: true,
    sanitizeHeaders: true,
    maxHeaderValueLength: 2048,
    maxHeaderCount: 40,
    removeDangerousHeaders: false
  )
}

// MARK: - Configuration Component

extension HeaderSecurityMiddleware: ConfigurationComponent {
  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    configuration.requestMiddlewares.append(self)
  }
}

// MARK: - Header Security Utilities

public struct HeaderSecurity {
  /// Validates a header name according to RFC 7230
  public static func isValidHeaderName(_ name: String) -> Bool {
    guard !name.isEmpty else { return false }

    // Header names must be tokens (RFC 7230)
    let tokenCharacters = CharacterSet.alphanumerics
      .union(CharacterSet(charactersIn: "!#$%&'*+-.^_`|~"))

    return name.rangeOfCharacter(from: tokenCharacters.inverted) == nil
  }

  /// Validates a header value according to RFC 7230
  public static func isValidHeaderValue(_ value: String) -> Bool {
    // Header values can contain any VCHAR, WSP, or obs-text
    // VCHAR = %x21-7E (visible characters)
    // WSP = SP / HTAB
    // obs-text = %x80-FF (obsolete text)

    for char in value.unicodeScalars {
      let code = char.value

      // VCHAR (visible characters)
      if code >= 0x21 && code <= 0x7E {
        continue
      }

      // WSP (space and tab)
      if code == 0x20 || code == 0x09 {
        continue
      }

      // obs-text (extended ASCII)
      if code >= 0x80 && code <= 0xFF {
        continue
      }

      // Invalid character
      return false
    }

    return true
  }

  /// Sanitizes a header value by removing invalid characters
  public static func sanitizeHeaderValue(_ value: String) -> String {
    String(
      value.unicodeScalars.compactMap { char in
        let code = char.value

        // Keep VCHAR, WSP, and obs-text
        if (code >= 0x21 && code <= 0x7E) || code == 0x20 || code == 0x09
          || (code >= 0x80 && code <= 0xFF)
        {
          return Character(char)
        }

        return nil
      }
    )
  }

  /// Checks if a string contains header injection patterns
  public static func containsInjectionAttempt(_ value: String) -> Bool {
    let injectionPatterns = [
      "\r\n", "\n", "\r",
      "%0d%0a", "%0a", "%0d",
      "\\r\\n", "\\n", "\\r",
    ]

    let lowercaseValue = value.lowercased()
    return injectionPatterns.contains { lowercaseValue.contains($0) }
  }
}
