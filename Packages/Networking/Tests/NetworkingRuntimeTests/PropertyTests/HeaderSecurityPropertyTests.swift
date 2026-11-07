import NetworkingCore
import PremiseCore
import PremiseStrategies
import PremiseTesting
import Testing

@testable import NetworkingRuntime

@Suite("Header security properties")
struct HeaderSecurityPropertyTests {
  @Test("Sanitizing a header value is idempotent and yields a valid value")
  func sanitizationContract() async throws {
    try await forAll(Self.untrustedHeaderValue, config: Self.config) { value in
      let sanitized = HeaderSecurity.sanitizeHeaderValue(HTTPHeaderValue(value))
      #expect(HeaderSecurity.sanitizeHeaderValue(sanitized) == sanitized)
      #expect(HeaderSecurity.isValidHeaderValue(sanitized).rawValue)
    }
  }

  @Test("Sanitization preserves valid field values")
  func validValuesArePreserved() async throws {
    try await forAll(Self.validHeaderValue, config: Self.config) { value in
      #expect(HeaderSecurity.sanitizeHeaderValue(HTTPHeaderValue(value)) == HTTPHeaderValue(value))
    }
  }

  @Test("Known injection forms are always detected")
  func injectionDetection() async throws {
    try await forAll(
      Self.safeHeaderValue,
      Self.injectionPattern,
      Self.safeHeaderValue,
      config: Self.config
    ) { prefix, pattern, suffix in
      #expect(
        HeaderSecurity.containsInjectionAttempt(HTTPHeaderValue(prefix + pattern + suffix)).rawValue
      )
    }
  }

  @Test("Safe field values never look like injection")
  func safeValuesDoNotTriggerInjectionDetection() async throws {
    try await forAll(Self.safeHeaderValue, config: Self.config) { value in
      #expect(!HeaderSecurity.containsInjectionAttempt(HTTPHeaderValue(value)).rawValue)
    }
  }

  @Test("RFC 7230 token names are accepted and forbidden characters are rejected")
  func headerNameValidation() async throws {
    try await forAll(Self.validHeaderName, config: Self.config) { name in
      #expect(HeaderSecurity.isValidHeaderName(HTTPHeaderName(name)).rawValue)
    }
    try await forAll(Self.validHeaderName, Self.forbiddenHeaderNameCharacter, config: Self.config) {
      prefix,
      forbidden in
      #expect(!HeaderSecurity.isValidHeaderName(HTTPHeaderName(prefix + forbidden)).rawValue)
    }
  }

  @Test("Field values reject every prohibited control character")
  func headerValueValidation() async throws {
    try await forAll(Self.validHeaderValue, config: Self.config) { value in
      #expect(HeaderSecurity.isValidHeaderValue(HTTPHeaderValue(value)).rawValue)
    }
    try await forAll(Self.safeHeaderValue, Self.prohibitedControlCharacter, config: Self.config) {
      prefix,
      controlCharacter in
      #expect(
        !HeaderSecurity.isValidHeaderValue(HTTPHeaderValue(prefix + controlCharacter)).rawValue
      )
    }
  }

  @Test("An empty header name is invalid")
  func emptyHeaderNameIsInvalid() {
    #expect(!HeaderSecurity.isValidHeaderName("").rawValue)
  }

  private static let config = PropertyConfig.bounded(runs: 40, shrinks: 160)
  private static let validHeaderName = Strategy<String>.strings(
    from: Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%&'*+-.^_`|~"),
    length: 1...20
  )
  private static let validHeaderValue = Strategy<String>.strings(
    from: Array(
      "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 !#$%&'*+-.^_`|~\\\t"
    ),
    length: 1...50
  )
  private static let safeHeaderValue = Strategy<String>.strings(
    from: Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 !#$&'*+-.^_`|~"),
    length: 0...30
  )
  private static let untrustedHeaderValue = Strategy<String>.strings(
    from: Array(
      "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 !#$%&'*+-.^_`|~\\\t"
        + "\r\n\u{0000}\u{007F}"
    ),
    length: 0...50
  )
  private static let injectionPattern = Strategy<String>.oneOf(
    ["\r\n", "\n", "\r", "%0d%0a", "%0a", "%0d", "\\r\\n", "\\n", "\\r"].map {
      Strategy<String>.constant($0)
    }
  )
  private static let forbiddenHeaderNameCharacter = Strategy<String>.oneOf(
    ["(", ")", "<", ">", "@", ",", ";", ":", "\\", "\"", "/", "[", "]", "?", "=", "{", "}"].map {
      Strategy<String>.constant($0)
    }
  )
  private static let prohibitedControlCharacter = Strategy<String>.oneOf(
    ["\u{0000}", "\u{0001}", "\u{0008}", "\u{000A}", "\u{000D}", "\u{001F}", "\u{007F}"].map {
      Strategy<String>.constant($0)
    }
  )
}
