import Foundation
import NetworkingCore

extension HTTPError {
  public enum SecurityError: Sendable {
    case headerInjection
    case maliciousContent
    case suspiciousActivity
    case rateLimitExceeded
  }
}

extension HTTPError.Category {
  public static func security(
    _ error: HTTPError.SecurityError,
    message: HTTPErrorDetail? = nil
  ) -> Self {
    let defaultMessage: HTTPErrorDetail
    switch error {
    case .headerInjection:
      defaultMessage = "Header injection attack detected"

    case .maliciousContent:
      defaultMessage = "Malicious content detected"

    case .suspiciousActivity:
      defaultMessage = "Suspicious activity detected"

    case .rateLimitExceeded:
      defaultMessage = "Rate limit exceeded"
    }

    return .custom("Security", message ?? defaultMessage)
  }
}

public struct HeaderSecurity {
  /// Validates a header name according to RFC 7230.
  public static func isValidHeaderName(_ name: HTTPHeaderName) -> HeaderValidationDecision {
    guard !name.isEmpty else { return false }

    let tokenCharacters = CharacterSet.alphanumerics
      .union(CharacterSet(charactersIn: "!#$%&'*+-.^_`|~"))

    return HeaderValidationDecision(
      name.rawValue.rangeOfCharacter(from: tokenCharacters.inverted) == nil
    )
  }

  /// Validates a header value according to RFC 7230.
  public static func isValidHeaderValue(_ value: HTTPHeaderValue) -> HeaderValidationDecision {
    for char in value.rawValue.unicodeScalars {
      let code = char.value

      if code >= 0x21 && code <= 0x7E {
        continue
      }

      if code == 0x20 || code == 0x09 {
        continue
      }

      if code >= 0x80 && code <= 0xFF {
        continue
      }

      return false
    }

    return true
  }

  /// Sanitizes a header value by removing invalid characters.
  public static func sanitizeHeaderValue(_ value: HTTPHeaderValue) -> HTTPHeaderValue {
    HTTPHeaderValue(
      String(
        value.rawValue.unicodeScalars.compactMap { char in
          let code = char.value

          if (code >= 0x21 && code <= 0x7E) || code == 0x20 || code == 0x09
            || (code >= 0x80 && code <= 0xFF)
          {
            return Character(char)
          }

          return nil
        }
      )
    )
  }

  /// Checks if a string contains header injection patterns.
  public static func containsInjectionAttempt(_ value: HTTPHeaderValue) -> HeaderValidationDecision
  {
    let injectionPatterns = [
      "\r\n", "\n", "\r",
      "%0d%0a", "%0a", "%0d",
      "\\r\\n", "\\n", "\\r",
    ]

    let lowercaseValue = value.lowercased()
    return HeaderValidationDecision(injectionPatterns.contains { lowercaseValue.contains($0) })
  }
}
