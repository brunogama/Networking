import Foundation
import NetworkingCore

/// Middleware that provides security validation and sanitization for HTTP headers.
public struct HeaderSecurityMiddleware: HTTPRequestMiddleware {
  // MARK: - Properties

  private let configuration: Configuration

  // MARK: - Initialization

  public init(configuration: Configuration = Configuration()) {
    self.configuration = configuration
  }

  // MARK: - HTTPRequestMiddleware

  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    try validateHeaderCount(in: request)

    return HTTPRequest(
      method: request.method,
      url: request.url,
      headers: try sanitizedHeaders(for: request),
      body: request.body,
      timeout: request.timeout
    )
  }

  // MARK: - Validation Methods

  private func validateHeaderCount(in request: HTTPRequest) throws {
    guard request.headers.count <= configuration.maxHeaderCount.rawValue else {
      let message =
        "Too many headers: \(request.headers.count) > \(configuration.maxHeaderCount.rawValue)"
      throw securityError(message, request: request)
    }
  }

  private func sanitizedHeaders(for request: HTTPRequest) throws -> HTTPHeaders {
    var headers: HTTPHeaders = [:]

    for (name, value) in request.headers {
      guard try shouldRetainHeader(name: name, value: value, request: request) else {
        continue
      }

      headers[name] = HTTPHeaderValue(sanitizeHeaderValue(value.rawValue))
    }

    return headers
  }

  private func shouldRetainHeader(
    name: HTTPHeaderName,
    value: HTTPHeaderValue,
    request: HTTPRequest
  ) throws -> Bool {
    if configuration.validateHeaderNames.rawValue {
      try validateHeaderName(name.rawValue, for: request)
    }

    if configuration.validateHeaderValues.rawValue {
      try validateHeaderValue(value.rawValue, for: request)
    }

    guard !isDangerousHeader(name) else {
      return false
    }

    return try passesCustomValidation(for: name, value: value, request: request)
  }

  private func isDangerousHeader(_ name: HTTPHeaderName) -> Bool {
    configuration.removeDangerousHeaders.rawValue
      && configuration.dangerousHeaders.contains(DangerousHeaderName(name.lowercased()))
  }

  private func passesCustomValidation(
    for name: HTTPHeaderName,
    value: HTTPHeaderValue,
    request: HTTPRequest
  ) throws -> Bool {
    guard let customValidator = configuration.customValidator else {
      return true
    }

    guard customValidator(name, value).rawValue else {
      if configuration.sanitizeHeaders.rawValue {
        return false
      }

      throw securityError("Header failed custom validation: \(name)", request: request)
    }

    return true
  }

  private func validateHeaderName(_ name: String, for request: HTTPRequest) throws {
    guard !name.isEmpty else {
      throw securityError("Empty header name", request: request)
    }

    let invalidCharacters = CharacterSet.controlCharacters
      .union(CharacterSet.whitespacesAndNewlines)
      .union(CharacterSet(charactersIn: "()<>@,;:\\\"/[]?={}"))

    if name.rangeOfCharacter(from: invalidCharacters) != nil {
      if configuration.sanitizeHeaders.rawValue {
        return
      }

      throw securityError("Invalid characters in header name: \(name)", request: request)
    }

    if containsInjectionPattern(name) {
      throw securityError("Potential header injection in name: \(name)", request: request)
    }
  }

  private func validateHeaderValue(_ value: String, for request: HTTPRequest) throws {
    try validateHeaderLength(value, request: request)
    try validateHeaderCharacters(value, request: request)
    try validateHeaderContent(value, request: request)
  }

  private func sanitizeHeaderValue(_ value: String) -> String {
    let allowedCharacters = CharacterSet.controlCharacters
      .subtracting(CharacterSet(charactersIn: "\t"))
      .inverted

    let components = value.components(separatedBy: allowedCharacters.inverted)
    let sanitized = components.joined()

    if sanitized.count > configuration.maxHeaderValueLength.rawValue {
      return String(sanitized.prefix(configuration.maxHeaderValueLength.rawValue))
    }

    return sanitized
  }

  private func containsInjectionPattern(_ value: String) -> Bool {
    let injectionPatterns = [
      "\r\n",
      "\n",
      "\r",
      "%0d%0a",
      "%0a",
      "%0d",
      "\\r\\n",
      "\\n",
      "\\r",
    ]

    let lowercaseValue = value.lowercased()

    for pattern in injectionPatterns where lowercaseValue.contains(pattern) {
      return true
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

    for pattern in suspiciousPatterns where lowercaseValue.contains(pattern) {
      return true
    }

    return false
  }

  private func validateHeaderLength(_ value: String, request: HTTPRequest) throws {
    guard value.count <= configuration.maxHeaderValueLength.rawValue else {
      let message =
        "Header value too long: \(value.count) > \(configuration.maxHeaderValueLength.rawValue)"
      throw securityError(message, request: request)
    }
  }

  private func validateHeaderCharacters(_ value: String, request: HTTPRequest) throws {
    let invalidCharacters = CharacterSet.controlCharacters.subtracting(
      CharacterSet(charactersIn: "\t")
    )

    if value.rangeOfCharacter(from: invalidCharacters) != nil {
      if configuration.sanitizeHeaders.rawValue {
        return
      }

      throw securityError(
        "Invalid control characters in header value: \(value.prefix(50))",
        request: request
      )
    }
  }

  private func validateHeaderContent(_ value: String, request: HTTPRequest) throws {
    if containsInjectionPattern(value) {
      throw securityError(
        "Potential header injection in value: \(value.prefix(50))",
        request: request
      )
    }

    if containsSuspiciousPatterns(value) {
      throw securityError("Suspicious patterns detected in header value", request: request)
    }
  }

  private func securityError(_ message: String, request: HTTPRequest) -> HTTPError {
    HTTPError(
      category: .security(.headerInjection, message: HTTPErrorDetail(message)),
      request: request
    )
  }
}
