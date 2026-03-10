// swiftlint:disable file_length
import Foundation
@testable import NetworkingDSL
import NetworkingRuntime
import NetworkingRuntimeDSL
import NetworkingTesting
import XCTest

// Comprehensive tests for specialized response types.
// swiftlint:disable:next type_body_length
final class SpecializedResponseTests: XCTestCase {
  struct TestUser: Codable, Sendable, Equatable {
    let id: Int
    let name: String
    let email: String
  }

  var testUser: TestUser!
  var testUserData: Data!
  var testResponse: HTTPResponse!
  var testRequest: HTTPRequest!

  override func setUpWithError() throws {
    try super.setUpWithError()

    testUser = TestUser(id: 123, name: "John Doe", email: "john@example.com")
    testUserData = try JSONEncoder().encode(testUser)

    testRequest = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users/123")!
    )

    testResponse = HTTPResponse(
      request: testRequest,
      status: HTTPStatus(rawValue: 200),
      headers: ["Content-Type": "application/json"],
      body: testUserData
    )
  }

  // MARK: - CachedResponse Tests

  func testCachedResponseBasicProperties() {
    // Given
    let cacheMetadata = CacheMetadata(ttl: 300, tags: ["user", "profile"])

    // When
    let cachedResponse = CachedResponse(
      response: testResponse,
      value: testUser,
      cacheMetadata: cacheMetadata,
      isCacheHit: true
    )

    // Then
    XCTAssertEqual(cachedResponse.response.status.rawValue, 200)
    XCTAssertEqual(cachedResponse.value, testUser)
    XCTAssertTrue(cachedResponse.isCacheHit.rawValue)
    XCTAssertEqual(cachedResponse.cacheMetadata.tags, ["user", "profile"])
  }

  func testCachedResponseFreshnessCalculation() {
    // Given
    let cacheMetadata = CacheMetadata(ttl: 300, tags: ["user"])

    let recentTimestamp = Date().addingTimeInterval(-60)  // 1 minute ago

    // When
    let cachedResponse = CachedResponse(
      response: testResponse,
      value: testUser,
      cacheMetadata: cacheMetadata,
      isCacheHit: true,
      cacheTimestamp: recentTimestamp
    )

    // Then
    XCTAssertTrue(cachedResponse.isFresh.rawValue, "Cache should be fresh within TTL")
    XCTAssertLessThan(cachedResponse.cacheAge, 300, "Cache age should be less than TTL")
  }

  func testCachedResponseExpiredCache() {
    // Given
    let cacheMetadata = CacheMetadata(ttl: 60, tags: ["user"])

    let oldTimestamp = Date().addingTimeInterval(-120)  // 2 minutes ago

    // When
    let cachedResponse = CachedResponse(
      response: testResponse,
      value: testUser,
      cacheMetadata: cacheMetadata,
      isCacheHit: true,
      cacheTimestamp: oldTimestamp
    )

    // Then
    XCTAssertFalse(cachedResponse.isFresh.rawValue, "Cache should be stale after TTL")
    XCTAssertGreaterThan(cachedResponse.cacheAge, 60, "Cache age should exceed TTL")
  }

  func testCachedResponseNoTTL() {
    // Given
    let cacheMetadata = CacheMetadata(ttl: nil, tags: ["user"])

    let oldTimestamp = Date().addingTimeInterval(-3600)  // 1 hour ago

    // When
    let cachedResponse = CachedResponse(
      response: testResponse,
      value: testUser,
      cacheMetadata: cacheMetadata,
      isCacheHit: true,
      cacheTimestamp: oldTimestamp
    )

    // Then
    XCTAssertTrue(cachedResponse.isFresh.rawValue, "Cache without TTL should always be fresh")
  }

  // MARK: - DecodableResponse Tests

  func testDecodableResponseBasicDecoding() throws {
    // When
    let decodableResponse = try DecodableResponse<TestUser>.decode(from: testResponse)

    // Then
    XCTAssertEqual(decodableResponse.value, testUser)
    XCTAssertEqual(decodableResponse.response.status.rawValue, 200)
    XCTAssertEqual(decodableResponse.decodingMetadata.decoder, "JSONDecoder")
    XCTAssertEqual(
      decodableResponse.decodingMetadata.originalDataSize.rawValue,
      testUserData.count
    )
    XCTAssertNotNil(decodableResponse.decodingMetadata.decodingDuration)
    XCTAssertGreaterThan(decodableResponse.decodingMetadata.decodingDuration ?? 0, 0)
  }

  func testDecodableResponseEmptyBody() {
    // Given
    let emptyResponse = HTTPResponse(
      request: testRequest,
      status: HTTPStatus(rawValue: 200),
      headers: [:],
      body: Optional<HTTPBody>.none
    )

    // When & Then
    XCTAssertThrowsError(try DecodableResponse<TestUser>.decode(from: emptyResponse)) { error in
      guard let httpError = error as? HTTPError else {
        XCTFail("Expected HTTPError")
        return
      }

      switch httpError.category {
      case .decoding(let message):
        XCTAssertTrue(message.contains("empty"), "Error should mention empty body")

      default:
        XCTFail("Expected decoding error")
      }
    }
  }

  func testDecodableResponseInvalidJSON() {
    // Given
    let invalidData = Data("invalid json".utf8)
    let invalidResponse = HTTPResponse(
      request: testRequest,
      status: HTTPStatus(rawValue: 200),
      headers: ["Content-Type": "application/json"],
      body: invalidData
    )

    // When & Then
    XCTAssertThrowsError(try DecodableResponse<TestUser>.decode(from: invalidResponse)) {
      error in
      guard let httpError = error as? HTTPError else {
        XCTFail("Expected HTTPError")
        return
      }

      switch httpError.category {
      case .decoding(let message):
        XCTAssertTrue(
          message.contains("Failed to decode"),
          "Error should mention decoding failure"
        )

      default:
        XCTFail("Expected decoding error")
      }
    }
  }

  func testDecodableResponsePerformanceMetrics() throws {
    // Given
    let largeData = try JSONEncoder().encode(Array(0..<1000).map { _ in testUser })
    let largeResponse = HTTPResponse(
      request: testRequest,
      status: HTTPStatus(rawValue: 200),
      headers: ["Content-Type": "application/json"],
      body: largeData
    )

    // When
    let decodableResponse = try DecodableResponse<[TestUser]>.decode(from: largeResponse)

    // Then
    XCTAssertNotNil(decodableResponse.decodingRate, "Should have decoding rate")
    if let rate = decodableResponse.decodingRate {
      XCTAssertGreaterThan(rate, 0, "Decoding rate should be positive")
      print("Decoding rate: \(rate) bytes/second")
    }
  }

  func testDecodableResponseCustomDecoder() throws {
    // Given
    let customDecoder = JSONDecoder()
    customDecoder.dateDecodingStrategy = .iso8601

    // When
    let decodableResponse = try DecodableResponse<TestUser>.decode(
      from: testResponse,
      using: customDecoder
    )

    // Then
    XCTAssertEqual(decodableResponse.value, testUser)
    XCTAssertEqual(decodableResponse.decodingMetadata.decoder, "JSONDecoder")
  }

  // MARK: - CachedDecodableResponse Tests

  func testCachedDecodableResponseCreation() throws {
    // Given
    let cacheMetadata = CacheMetadata(ttl: 300, tags: ["user"])

    let decodableResponse = try DecodableResponse<TestUser>.decode(from: testResponse)

    // When
    let cachedDecodableResponse = CachedDecodableResponse(
      decodable: decodableResponse,
      cacheMetadata: cacheMetadata,
      isCacheHit: true
    )

    // Then
    XCTAssertEqual(cachedDecodableResponse.value, testUser)
    XCTAssertTrue(cachedDecodableResponse.isCacheHit.rawValue)
    XCTAssertTrue(cachedDecodableResponse.isFresh.rawValue)
    XCTAssertNotNil(cachedDecodableResponse.decodingRate)
  }

  func testCachedDecodableResponseDirectInitializer() {
    // Given
    let cacheMetadata = CacheMetadata(ttl: 300, tags: ["user"])

    let decodingMetadata = DecodableResponse<TestUser>.DecodingMetadata(
      decoder: "JSONDecoder",
      decodedAt: Date(),
      originalDataSize: DecodedDataSize(testUserData.count),
      decodingDuration: 0.001
    )

    // When
    let cachedDecodableResponse = CachedDecodableResponse(
      response: testResponse,
      value: testUser,
      cacheMetadata: cacheMetadata,
      decodingMetadata: decodingMetadata,
      isCacheHit: false
    )

    // Then
    XCTAssertEqual(cachedDecodableResponse.value, testUser)
    XCTAssertFalse(cachedDecodableResponse.isCacheHit.rawValue)
    XCTAssertEqual(
      cachedDecodableResponse.decodingMetadata.originalDataSize.rawValue,
      testUserData.count
    )
  }

  func testCachedDecodableResponseDecodeFromCached() throws {
    // Given
    let cacheMetadata = CacheMetadata(ttl: 300, tags: ["user"])

    let cachedResponse: CachedResponse<HTTPResponse> = CachedResponse(
      response: testResponse,
      value: testResponse,
      cacheMetadata: cacheMetadata,
      isCacheHit: true
    )

    // When
    let cachedDecodableResponse = try CachedDecodableResponse<TestUser>.decode(
      from: cachedResponse
    )

    // Then
    XCTAssertEqual(cachedDecodableResponse.value, testUser)
    XCTAssertTrue(cachedDecodableResponse.isCacheHit.rawValue)
    XCTAssertNotNil(cachedDecodableResponse.decodingRate)
  }

  // MARK: - ValidatedResponseProtocol Conformance Tests

  func testCachedResponseProtocolConformance() {
    // Given
    let cacheMetadata = CacheMetadata(ttl: 300, tags: ["user"])

    // When
    let cachedResponse = CachedResponse(
      response: testResponse,
      value: testUser,
      cacheMetadata: cacheMetadata
    )

    // Then
    XCTAssertEqual(cachedResponse.response.status.rawValue, 200)
    XCTAssertEqual(cachedResponse.value, testUser)
    XCTAssertEqual(cachedResponse.validationResults.count, 1)
  }

  func testDecodableResponseProtocolConformance() throws {
    // When
    let decodableResponse = try DecodableResponse<TestUser>.decode(from: testResponse)

    // Then
    XCTAssertEqual(decodableResponse.response.status.rawValue, 200)
    XCTAssertEqual(decodableResponse.value, testUser)
    XCTAssertEqual(decodableResponse.validationResults.count, 1)
  }

  func testCachedDecodableResponseProtocolConformance() throws {
    // Given
    let cacheMetadata = CacheMetadata(ttl: 300, tags: ["user"])

    let decodableResponse = try DecodableResponse<TestUser>.decode(from: testResponse)

    // When
    let cachedDecodableResponse = CachedDecodableResponse(
      decodable: decodableResponse,
      cacheMetadata: cacheMetadata
    )

    // Then
    XCTAssertEqual(cachedDecodableResponse.response.status.rawValue, 200)
    XCTAssertEqual(cachedDecodableResponse.value, testUser)
    XCTAssertEqual(cachedDecodableResponse.validationResults.count, 1)
  }
}
