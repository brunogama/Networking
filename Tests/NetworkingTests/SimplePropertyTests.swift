import XCTest
import SwiftCheck
@testable import Networking
import Foundation

/// Property-based tests for core networking functionality
final class SimplePropertyTests: XCTestCase {
  // MARK: - HTTPRequest Property Tests

  func testHTTPRequestProperties() {
    // Property: HTTPRequest should preserve all data during creation
    property("HTTPRequest preserves data through initialization")
      <- forAll {
        (method: HTTPMethod, urlString: String, headerCount: Int) in
        guard
          let url = URL(
            string: "https://example.com/\(urlString.replacingOccurrences(of: " ", with: "%20"))"
          )
        else {
          return Discard()
        }

        let headers = (0..<max(0, headerCount % 10)).reduce(into: [String: String]()) {
          result,
          index in
          result["Header-\(index)"] = "Value-\(index)"
        }

        let originalRequest = HTTPRequest(
          method: method,
          url: url,
          headers: headers,
          body: nil
        )

        // Test that request maintains identity
        let reconstructedRequest = HTTPRequest(
          method: originalRequest.method,
          url: originalRequest.url,
          headers: originalRequest.headers,
          body: originalRequest.body
        )

        return originalRequest.method == reconstructedRequest.method
          && originalRequest.url == reconstructedRequest.url
          && originalRequest.headers == reconstructedRequest.headers
          && originalRequest.body == reconstructedRequest.body
      }
  }

  func testHTTPStatusProperties() {
    property("HTTPStatus rawValue round-trip")
      <- forAll { (statusCode: Int) in
        // Only test valid HTTP status codes
        guard statusCode >= 100 && statusCode <= 599 else { return Discard() }

        let status = HTTPStatus(rawValue: statusCode)
        return status.rawValue == statusCode
      }

    property("HTTPStatus categories are mutually exclusive")
      <- forAll { (statusCode: Int) in
        guard statusCode >= 100 && statusCode <= 599 else { return Discard() }

        let status = HTTPStatus(rawValue: statusCode)
        let categories = [
          status.isInformational,
          status.isSuccess,
          status.isRedirection,
          status.isClientError,
          status.isServerError,
        ]

        // Exactly one category should be true
        return categories.filter { $0 }.count == 1
      }
  }

  // MARK: - URL Construction Property Tests

  func testURLConstructionProperties() {
    property("URL query parameters are properly encoded")
      <- forAll { (baseURL: String, params: [String: String]) in
        guard
          let base = URL(
            string: "https://example.com/\(baseURL.replacingOccurrences(of: " ", with: "%20"))"
          )
        else {
          return Discard()
        }

        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let finalURL = components?.url else { return false }

        // Property: All parameters should be recoverable from the constructed URL
        let recoveredComponents = URLComponents(url: finalURL, resolvingAgainstBaseURL: false)
        let recoveredParams =
          recoveredComponents?.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
          } ?? [:]

        return recoveredParams == params
      }
  }

  // MARK: - Error Handling Property Tests

  func testHTTPErrorProperties() {
    property("HTTPError maintains category consistency")
      <- forAll { (statusCode: Int) in
        guard statusCode >= 400 && statusCode <= 599 else { return Discard() }

        let status = HTTPStatus(rawValue: statusCode)
        let error = HTTPError(category: .http(status), underlyingError: nil)

        switch error.category {
        case .http(let errorStatus):
          return errorStatus.rawValue == statusCode

        default:
          return false
        }
      }

    property("HTTPError recovery context is consistent")
      <- forAll { (useTimeoutError: Bool) in
        let category: HTTPError.Category = useTimeoutError ? .timeout : .cancelled
        let error = HTTPError(category: category)

        let expectedRecoverable = useTimeoutError  // timeout is recoverable, cancelled is not
        let actualRecoverable = error.recoveryCategory != .nonRecoverable

        return expectedRecoverable == actualRecoverable
      }
  }

  // MARK: - Caching Property Tests

  func testCacheMetadataProperties() {
    property("CacheMetadata TTL calculations are consistent")
      <- forAll { (ttlSeconds: Int) in
        guard ttlSeconds >= 0 && ttlSeconds <= 86_400 else { return Discard() }  // Max 24 hours

        let ttl = TimeInterval(ttlSeconds)
        let metadata = CacheMetadata(ttl: ttl, tags: ["test"])

        // Property: TTL should be preserved
        return metadata.ttl == ttl && metadata.tags == ["test"]
      }
  }

  // MARK: - Response Processing Property Tests

  func testResponseValidationProperties() {
    property("ValidatedResponse maintains value consistency")
      <- forAll { (statusCode: Int) in
        guard statusCode >= 200 && statusCode <= 299 else { return Discard() }

        let status = HTTPStatus(rawValue: statusCode)
        let testData = "test data"

        let response = HTTPResponse(
          request: HTTPRequest(method: .get, url: URL(string: "https://example.com")!),
          status: status,
          headers: [:],
          body: testData.data(using: .utf8)
        )

        let validatedResponse = ValidatedResponse.success(response: response, value: testData)

        // Property: Valid responses should maintain their values
        return validatedResponse.isValid && validatedResponse.value == testData
          && validatedResponse.response.status == status
      }
  }

  // MARK: - JSON Decoding Property Tests

  func testJSONDecodingProperties() {
    struct TestModel: Codable, Equatable {
      let id: Int
      let name: String
      let active: Bool
    }

    property("JSON encoding/decoding round-trip preserves data")
      <- forAll { (id: Int, name: String, active: Bool) in
        // Sanitize name to ensure valid JSON
        let sanitizedName = name.replacingOccurrences(of: "\"", with: "'")
        guard !sanitizedName.isEmpty else { return Discard() }

        let original = TestModel(id: id, name: sanitizedName, active: active)

        do {
          let encoded = try JSONEncoder().encode(original)
          let decoded = try JSONDecoder().decode(TestModel.self, from: encoded)
          return original == decoded
        } catch {
          return false
        }
      }
  }
}

// MARK: - SwiftCheck Generators

extension HTTPMethod: Arbitrary {
  public static var arbitrary: Gen<HTTPMethod> {
    Gen<HTTPMethod>.fromElements(of: [.get, .post, .put, .delete, .patch, .head, .options])
  }
}

extension String {
  static var arbitraryURLPath: Gen<String> {
    Gen<String>.sized { size in
      let pathComponents = (0..<Swift.max(1, size % 5)).map { _ in
        String.arbitrary.resize(10).generate
      }
      return Gen<String>.pure(pathComponents.joined(separator: "/"))
    }
  }
}

// Custom generators for network-specific types
extension Gen where A == URL {
  static var arbitraryHTTPURL: Gen<URL> {
    String.arbitraryURLPath.map { path in
      URL(string: "https://example.com/\(path)")!
    }
  }
}
