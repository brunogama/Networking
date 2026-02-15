import XCTest
@testable import Networking
import Foundation

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
final class HeaderSecurityMiddlewareTests: XCTestCase {
  // MARK: - Test Properties

  private var middleware: HeaderSecurityMiddleware!
  private var strictConfig: HeaderSecurityMiddleware.Configuration!
  private var permissiveConfig: HeaderSecurityMiddleware.Configuration!

  // MARK: - Setup & Teardown

  override func setUp() {
    super.setUp()
    strictConfig = .strict
    permissiveConfig = .permissive
    middleware = HeaderSecurityMiddleware(configuration: strictConfig)
  }

  override func tearDown() {
    middleware = nil
    strictConfig = nil
    permissiveConfig = nil
    super.tearDown()
  }

  // MARK: - Configuration Tests

  func testStrictConfigurationValues() {
    XCTAssertTrue(strictConfig.validateHeaderNames)
    XCTAssertTrue(strictConfig.validateHeaderValues)
    XCTAssertTrue(strictConfig.sanitizeHeaders)
    XCTAssertEqual(strictConfig.maxHeaderValueLength, 2048)
    XCTAssertEqual(strictConfig.maxHeaderCount, 30)
    XCTAssertTrue(strictConfig.removeDangerousHeaders)
  }

  func testPermissiveConfigurationValues() {
    XCTAssertTrue(permissiveConfig.validateHeaderNames)
    XCTAssertTrue(permissiveConfig.validateHeaderValues)
    XCTAssertTrue(permissiveConfig.sanitizeHeaders)
    XCTAssertEqual(permissiveConfig.maxHeaderValueLength, 8192)
    XCTAssertEqual(permissiveConfig.maxHeaderCount, 100)
    XCTAssertFalse(permissiveConfig.removeDangerousHeaders)
  }

  func testAPIConfigurationValues() {
    let apiConfig = HeaderSecurityMiddleware.Configuration.api
    XCTAssertTrue(apiConfig.validateHeaderNames)
    XCTAssertTrue(apiConfig.validateHeaderValues)
    XCTAssertFalse(apiConfig.sanitizeHeaders)  // Fail fast for APIs
    XCTAssertEqual(apiConfig.maxHeaderValueLength, 1024)
    XCTAssertEqual(apiConfig.maxHeaderCount, 20)
    XCTAssertTrue(apiConfig.removeDangerousHeaders)
  }

  // MARK: - Header Injection Detection Tests

  func testCRLFInjectionDetection() async throws {
    // Use API config that doesn't sanitize, so it throws errors
    let crlfMiddleware = HeaderSecurityMiddleware(configuration: .api)

    let maliciousHeaders = [
      "X-Test": "value\r\nX-Injected: malicious",
      "Authorization": "Bearer token\nLocation: http://evil.com",
    ]

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://example.com")!,
      headers: maliciousHeaders
    )

    do {
      _ = try await crlfMiddleware.modifyRequest(request)
      XCTFail("Should have thrown security error for CRLF injection")
    } catch let error as HTTPError {
      switch error.category {
      case .custom("Security", _):
        XCTAssertTrue(true, "Correctly detected CRLF injection")

      default:
        XCTFail("Expected security error, got: \(error)")
      }
    }
  }

  func testURLEncodedInjectionDetection() async throws {
    let maliciousHeaders = [
      "X-Test": "value%0d%0aX-Injected: malicious",
      "Custom-Header": "normal%0aevil",
    ]

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://example.com")!,
      headers: maliciousHeaders
    )

    do {
      _ = try await middleware.modifyRequest(request)
      XCTFail("Should have thrown security error for URL-encoded injection")
    } catch let error as HTTPError {
      switch error.category {
      case .custom("Security", _):
        XCTAssertTrue(true, "Correctly detected URL-encoded injection")

      default:
        XCTFail("Expected security error, got: \(error)")
      }
    }
  }

  func testSuspiciousPatternDetection() async throws {
    let suspiciousHeaders = [
      "X-Test": "<script>alert('xss')</script>",
      "Custom": "javascript:alert(1)",
      "Another": "data:text/html,<script>evil</script>",
    ]

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://example.com")!,
      headers: suspiciousHeaders
    )

    do {
      _ = try await middleware.modifyRequest(request)
      XCTFail("Should have thrown security error for suspicious patterns")
    } catch let error as HTTPError {
      switch error.category {
      case .custom("Security", _):
        XCTAssertTrue(true, "Correctly detected suspicious patterns")

      default:
        XCTFail("Expected security error, got: \(error)")
      }
    }
  }

  // MARK: - Header Validation Tests

  func testValidHeaderNamesAccepted() async throws {
    let validHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer token123",
      "X-Custom-Header": "value",
      "User-Agent": "Networking/1.0",
    ]

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://example.com")!,
      headers: validHeaders
    )

    let result = try await middleware.modifyRequest(request)
    XCTAssertEqual(result.headers.count, validHeaders.count)
  }

  func testInvalidHeaderNamesRejected() async throws {
    let invalidHeaders = [
      "": "empty-name",
      "header with spaces": "invalid",
      "header\twith\ttabs": "invalid",
      "header@with!symbols": "invalid",
    ]

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://example.com")!,
      headers: invalidHeaders
    )

    do {
      _ = try await middleware.modifyRequest(request)
      XCTFail("Should have rejected invalid header names")
    } catch let error as HTTPError {
      switch error.category {
      case .custom("Security", _):
        XCTAssertTrue(true, "Correctly rejected invalid header names")

      default:
        XCTFail("Expected security error, got: \(error)")
      }
    }
  }

  // MARK: - Header Sanitization Tests

  func testHeaderValueSanitization() async throws {
    let sanitizingMiddleware = HeaderSecurityMiddleware(
      configuration: HeaderSecurityMiddleware.Configuration(sanitizeHeaders: true)
    )

    let headersWithControlChars = [
      "X-Test": "value\u{0001}with\u{0002}control\u{0003}chars",
      "X-Another": "normal\ttab\tvalue",  // Tab should be preserved
    ]

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://example.com")!,
      headers: headersWithControlChars
    )

    let result = try await sanitizingMiddleware.modifyRequest(request)

    XCTAssertEqual(result.headers["X-Test"], "valuewithcontrolchars")
    XCTAssertEqual(result.headers["X-Another"], "normal\ttab\tvalue")
  }

  func testHeaderValueLengthLimiting() async throws {
    let longValue = String(repeating: "a", count: 3000)
    let headers = ["X-Long": longValue]

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://example.com")!,
      headers: headers
    )

    do {
      _ = try await middleware.modifyRequest(request)
      XCTFail("Should have rejected header value that's too long")
    } catch let error as HTTPError {
      switch error.category {
      case .custom("Security", let message):
        XCTAssertTrue(message.contains("too long"), "Expected 'too long' in message: '\(message)'")

      default:
        XCTFail("Expected security error about length, got: \(error)")
      }
    }
  }

  // MARK: - Dangerous Header Removal Tests

  func testDangerousHeadersRemoved() async throws {
    let dangerousHeaders = [
      "x-forwarded-for": "192.168.1.1",
      "X-Real-IP": "10.0.0.1",
      "x-forwarded-host": "evil.com",
      "Content-Type": "application/json",  // Should be preserved
      "Authorization": "Bearer token",  // Should be preserved
    ]

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://example.com")!,
      headers: dangerousHeaders
    )

    let result = try await middleware.modifyRequest(request)

    // Dangerous headers should be removed
    XCTAssertNil(result.headers["x-forwarded-for"])
    XCTAssertNil(result.headers["X-Real-IP"])
    XCTAssertNil(result.headers["x-forwarded-host"])

    // Safe headers should be preserved
    XCTAssertEqual(result.headers["Content-Type"], "application/json")
    XCTAssertEqual(result.headers["Authorization"], "Bearer token")
  }

  func testPermissiveConfigDoesNotRemoveDangerousHeaders() async throws {
    let permissiveMiddleware = HeaderSecurityMiddleware(configuration: permissiveConfig)

    let headers = [
      "x-forwarded-for": "192.168.1.1",
      "Content-Type": "application/json",
    ]

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://example.com")!,
      headers: headers
    )

    let result = try await permissiveMiddleware.modifyRequest(request)

    // In permissive config, dangerous headers should be preserved
    XCTAssertEqual(result.headers["x-forwarded-for"], "192.168.1.1")
    XCTAssertEqual(result.headers["Content-Type"], "application/json")
  }

  // MARK: - Header Count Limit Tests

  func testHeaderCountLimit() async throws {
    var tooManyHeaders: [String: String] = [:]
    for i in 0..<40 {  // Exceeds strict limit of 30
      tooManyHeaders["X-Header-\(i)"] = "value-\(i)"
    }

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://example.com")!,
      headers: tooManyHeaders
    )

    do {
      _ = try await middleware.modifyRequest(request)
      XCTFail("Should have rejected too many headers")
    } catch let error as HTTPError {
      switch error.category {
      case .custom("Security", let message):
        XCTAssertTrue(message.contains("Too many headers"))

      default:
        XCTFail("Expected security error about header count, got: \(error)")
      }
    }
  }

  // MARK: - Custom Validator Tests

  func testCustomValidatorRejectsHeaders() async throws {
    let customConfig = HeaderSecurityMiddleware.Configuration(
      customValidator: { name, value in
        // Reject headers containing "secret"
        !name.lowercased().contains("secret") && !value.lowercased().contains("secret")
      }
    )

    let customMiddleware = HeaderSecurityMiddleware(configuration: customConfig)

    let headers = [
      "X-Secret-Key": "value",
      "Authorization": "secret-token",
      "Content-Type": "application/json",
    ]

    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://example.com")!,
      headers: headers
    )

    let result = try await customMiddleware.modifyRequest(request)

    // Headers with "secret" should be removed
    XCTAssertNil(result.headers["X-Secret-Key"])
    XCTAssertNil(result.headers["Authorization"])

    // Safe headers should be preserved
    XCTAssertEqual(result.headers["Content-Type"], "application/json")
  }

  // MARK: - Integration Tests

  func testCompleteSecurityValidation() async throws {
    let mixedHeaders = [
      "Content-Type": "application/json",
      "Authorization": "Bearer valid-token",
      "X-Custom": "safe-value",
      "x-forwarded-for": "192.168.1.1",  // Should be removed
      "User-Agent": "Networking/1.0",
    ]

    let request = HTTPRequest(
      method: .post,
      url: URL(string: "https://api.example.com/data")!,
      headers: mixedHeaders,
      body: Data("test".utf8)
    )

    let result = try await middleware.modifyRequest(request)

    // Verify safe headers are preserved
    XCTAssertEqual(result.headers["Content-Type"], "application/json")
    XCTAssertEqual(result.headers["Authorization"], "Bearer valid-token")
    XCTAssertEqual(result.headers["X-Custom"], "safe-value")
    XCTAssertEqual(result.headers["User-Agent"], "Networking/1.0")

    // Verify dangerous header is removed
    XCTAssertNil(result.headers["x-forwarded-for"])

    // Verify request integrity is preserved
    XCTAssertEqual(result.method, .post)
    XCTAssertEqual(result.url, URL(string: "https://api.example.com/data")!)
    XCTAssertEqual(result.body, Data("test".utf8))
  }
}

// MARK: - Helper Extensions

extension HeaderSecurityMiddlewareTests {
  /// Creates a test request with specified headers
  private func createTestRequest(headers: [String: String]) -> HTTPRequest {
    HTTPRequest(
      method: .get,
      url: URL(string: "https://example.com")!,
      headers: headers
    )
  }

  /// Verifies that a security error was thrown
  private func verifySecurityError(_ error: Error, expectedMessage: String? = nil) {
    guard let httpError = error as? HTTPError else {
      XCTFail("Expected HTTPError, got: \(error)")
      return
    }

    switch httpError.category {
    case .custom("Security", let message):
      if let expectedMessage = expectedMessage {
        XCTAssertTrue(
          message.contains(expectedMessage),
          "Expected message '\(expectedMessage)' in error: \(message)"
        )
      }

    default:
      XCTFail("Expected security error, got: \(httpError.category)")
    }
  }
}
