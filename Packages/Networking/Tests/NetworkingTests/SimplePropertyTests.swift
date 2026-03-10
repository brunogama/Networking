import Foundation
@testable import Networking
import NetworkingTesting
import SwiftCheck
import XCTest

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

                let headers = (0 ..< max(0, headerCount % 10)).reduce(into: [String: String]()) {
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
                guard statusCode >= 100, statusCode <= 599 else { return Discard() }

                let status = HTTPStatus(rawValue: statusCode)
                return status.rawValue == statusCode
            }

        property("HTTPStatus categories are mutually exclusive")
            <- forAll { (statusCode: Int) in
                guard statusCode >= 100, statusCode <= 599 else { return Discard() }

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
                guard statusCode >= 400, statusCode <= 599 else { return Discard() }

                let status = HTTPStatus(rawValue: statusCode)
                let error = HTTPError(category: .http(status), underlyingError: nil)

                switch error.category {
                case let .http(errorStatus):
                    return errorStatus.rawValue == statusCode

                default:
                    return false
                }
            }

        property("HTTPError recovery context is consistent")
            <- forAll { (useTimeoutError: Bool) in
                let category: HTTPError.Category = useTimeoutError ? .timeout : .cancelled
                let error = HTTPError(category: category)

                let expectedRecoverable = useTimeoutError // timeout is recoverable, cancelled is not
                let actualRecoverable = error.recoveryCategory != .nonRecoverable

                return expectedRecoverable == actualRecoverable
            }
    }

    // MARK: - Caching Property Tests

    func testCacheMetadataProperties() {
        property("CacheMetadata TTL calculations are consistent")
            <- forAll { (ttlSeconds: Int) in
                guard ttlSeconds >= 0, ttlSeconds <= 86400 else { return Discard() } // Max 24 hours

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
                guard statusCode >= 200, statusCode <= 299 else { return Discard() }

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

    // MARK: - HTTPMethod Property Tests

    func testHTTPMethodNormalizationProperties() {
        property("HTTPMethod uppercases any input string")
            <- forAll { (methodString: String) in
                guard !methodString.isEmpty else { return Discard() }
                let method = HTTPMethod(rawValue: methodString)
                return method.rawValue == methodString.uppercased()
            }

        property("HTTPMethod equality is reflexive")
            <- forAll { (method: HTTPMethod) in
                method == method
            }

        property("HTTPMethod rawValue round-trip preserves identity")
            <- forAll { (method: HTTPMethod) in
                let reconstructed = HTTPMethod(rawValue: method.rawValue)
                return reconstructed == method
            }

        property("HTTPMethod hash consistency with equality")
            <- forAll { (m1: HTTPMethod, m2: HTTPMethod) in
                // If two methods are equal, they must have equal hash values
                if m1 == m2 {
                    return m1.hashValue == m2.hashValue
                }
                return true
            }

        property("HTTPMethod string literal normalization")
            <- forAll { (useUppercase: Bool) in
                let input = useUppercase ? "GET" : "get"
                let method = HTTPMethod(stringLiteral: input)
                return method.rawValue == "GET"
            }
    }

    // MARK: - HTTPStatus Extended Property Tests

    func testHTTPStatusExtendedProperties() {
        property("HTTPStatus equality is reflexive")
            <- forAll { (statusCode: Int) in
                guard statusCode >= 100, statusCode <= 599 else { return Discard() }
                let status = HTTPStatus(rawValue: statusCode)
                return status == status
            }

        property("HTTPStatus hash consistency with equality")
            <- forAll { (s1Code: Int, s2Code: Int) in
                guard s1Code >= 100, s1Code <= 599 else { return Discard() }
                guard s2Code >= 100, s2Code <= 599 else { return Discard() }

                let s1 = HTTPStatus(rawValue: s1Code)
                let s2 = HTTPStatus(rawValue: s2Code)

                if s1 == s2 {
                    return s1.hashValue == s2.hashValue
                }
                return true
            }

        property("HTTPStatus category ranges are correct")
            <- forAll { (statusCode: Int) in
                guard statusCode >= 100, statusCode <= 599 else { return Discard() }
                let status = HTTPStatus(rawValue: statusCode)

                let expectedInformational = (100 ... 199).contains(statusCode)
                let expectedSuccess = (200 ... 299).contains(statusCode)
                let expectedRedirection = (300 ... 399).contains(statusCode)
                let expectedClientError = (400 ... 499).contains(statusCode)
                let expectedServerError = (500 ... 599).contains(statusCode)

                return status.isInformational == expectedInformational
                    && status.isSuccess == expectedSuccess
                    && status.isRedirection == expectedRedirection
                    && status.isClientError == expectedClientError
                    && status.isServerError == expectedServerError
            }
    }

    // MARK: - InterceptorContext Property Tests

    func testInterceptorContextIncrementProperties() {
        property("InterceptorContext incrementingAttempt increases count by 1")
            <- forAll { (context: InterceptorContext) in
                let incremented = context.incrementingAttempt()
                return incremented.attemptCount == context.attemptCount + 1
            }

        property("InterceptorContext incrementingAttempt preserves path")
            <- forAll { (context: InterceptorContext) in
                let incremented = context.incrementingAttempt()
                return incremented.path == context.path
            }

        property("InterceptorContext incrementingAttempt preserves method")
            <- forAll { (context: InterceptorContext) in
                let incremented = context.incrementingAttempt()
                return incremented.method == context.method
            }

        property("InterceptorContext incrementingAttempt preserves metadata count")
            <- forAll { (context: InterceptorContext) in
                let incremented = context.incrementingAttempt()
                return incremented.metadata.count == context.metadata.count
            }

        property("InterceptorContext multiple increments are additive")
            <- forAll { (context: InterceptorContext, n: UInt8) in
                let incrementCount = Int(n % 10)
                var current = context
                for _ in 0 ..< incrementCount {
                    current = current.incrementingAttempt()
                }
                return current.attemptCount == context.attemptCount + incrementCount
            }
    }

    func testInterceptorContextMetadataProperties() {
        property("InterceptorContext addingMetadata preserves existing keys")
            <- forAll { (context: InterceptorContext) in
                let newMetadata: [String: AnySendable] = ["newTestKey": .string("newValue")]
                let updated = context.addingMetadata(newMetadata)

                // All original keys should still be present
                for key in context.metadata.keys {
                    guard updated.metadata[key] != nil else { return false }
                }
                return true
            }

        property("InterceptorContext addingMetadata includes new keys")
            <- forAll { (context: InterceptorContext, newValue: Int) in
                let newMetadata: [String: AnySendable] = ["testKey": .int(newValue)]
                let updated = context.addingMetadata(newMetadata)

                guard case let .int(storedValue) = updated.metadata["testKey"] else {
                    return false
                }
                return storedValue == newValue
            }

        property("InterceptorContext addingMetadata uses right-bias override")
            <- forAll { (newValue: Int) in
                let original = InterceptorContext(
                    path: "/test",
                    method: .get,
                    attemptCount: 0,
                    metadata: ["key": .int(100)]
                )
                let updated = original.addingMetadata(["key": .int(newValue)])

                guard case let .int(storedValue) = updated.metadata["key"] else {
                    return false
                }
                return storedValue == newValue
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
            let pathComponents = (0 ..< Swift.max(1, size % 5)).map { _ in
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

// InterceptorContext generator for property tests
extension InterceptorContext: Arbitrary {
    public static var arbitrary: Gen<InterceptorContext> {
        Gen<InterceptorContext>.compose { composer in
            // Generate path segments
            let segmentCount = composer.generate(using: Gen.choose((1, 4)))
            let pathChars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
            let pathParts = (0 ..< segmentCount).map { _ -> String in
                let length = composer.generate(using: Gen.choose((1, 8)))
                let chars = (0 ..< length).compactMap { _ -> Character? in
                    composer.generate(using: Gen<Character>.fromElements(of: pathChars))
                }
                return String(chars)
            }
            let path = "/" + pathParts.joined(separator: "/")

            // Generate method
            let method = composer.generate(using: HTTPMethod.arbitrary)

            // Generate attempt count (0-50)
            let attemptCount = composer.generate(using: Gen.choose((0, 50)))

            // Generate metadata (0-3 entries)
            let metadataCount = composer.generate(using: Gen.choose((0, 3)))
            var metadata: [String: AnySendable] = [:]
            for i in 0 ..< metadataCount {
                let useString = composer.generate(using: Bool.arbitrary)
                if useString {
                    metadata["key\(i)"] = .string("value\(i)")
                } else {
                    let intVal = composer.generate(using: Int.arbitrary)
                    metadata["key\(i)"] = .int(intVal)
                }
            }

            return InterceptorContext(
                path: path,
                method: method,
                attemptCount: attemptCount,
                metadata: metadata
            )
        }
    }
}
