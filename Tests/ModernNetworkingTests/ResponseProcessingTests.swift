import XCTest
@testable import ModernNetworking
import Foundation

final class ResponseProcessingTests: XCTestCase {
  struct TestUser: Codable, Sendable, Equatable {
    let id: Int
    let name: String
    let email: String
  }

  func createMockResponse(
    status: HTTPStatus = .ok,
    body: Data? = nil,
    headers: [String: String] = [:]
  ) -> HTTPResponse {
    let request = HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users/1")!
    )
    return HTTPResponse(
      request: request,
      status: status,
      headers: headers,
      body: body
    )
  }

  func testResponseChainCreation() {
    // Given
    let response = createMockResponse()

    // When
    let chain = response.chain()

    // Then
    XCTAssertEqual(chain.response.status.rawValue, 200)
    XCTAssertEqual(chain.value.status.rawValue, 200)
  }

  func testStatusValidation() throws {
    // Given
    let successResponse = createMockResponse(status: .ok)
    let errorResponse = createMockResponse(status: .badRequest)

    // When & Then - Success case
    XCTAssertNoThrow(try successResponse.chain().validate(.successStatus))

    // When & Then - Error case
    XCTAssertThrowsError(try errorResponse.chain().validate(.successStatus)) { error in
      XCTAssertTrue(error is HTTPError)
    }
  }

  func testContentTypeValidation() throws {
    // Given
    let jsonResponse = createMockResponse(
      headers: ["Content-Type": "application/json"]
    )
    let xmlResponse = createMockResponse(
      headers: ["Content-Type": "application/xml"]
    )

    // When & Then - Success case
    XCTAssertNoThrow(try jsonResponse.chain().validate(.json))

    // When & Then - Error case
    XCTAssertThrowsError(try xmlResponse.chain().validate(.json)) { error in
      XCTAssertTrue(error is HTTPError)
    }
  }

  func testJSONDecoding() throws {
    // Given
    let user = TestUser(id: 1, name: "John Doe", email: "john@example.com")
    let jsonData = try JSONEncoder().encode(user)
    let response = createMockResponse(
      body: jsonData,
      headers: ["Content-Type": "application/json"]
    )

    // When
    let decodedResponse =
      try response
      .chain()
      .validate(.successStatus)
      .validate(.json)
      .decode(JSONDecoderTransformer(TestUser.self))

    // Then
    XCTAssertEqual(decodedResponse.value, user)
    XCTAssertEqual(decodedResponse.response.status.rawValue, 200)
  }

  func testStringTransformation() throws {
    // Given
    let testString = "Hello, World!"
    let response = createMockResponse(body: testString.data(using: .utf8))

    // When
    let transformedResponse =
      try response
      .chain()
      .asString()

    // Then
    XCTAssertEqual(transformedResponse.value, testString)
  }

  func testMethodChaining() throws {
    // Given
    let user = TestUser(id: 1, name: "John Doe", email: "john@example.com")
    let jsonData = try JSONEncoder().encode(user)
    let response = createMockResponse(
      status: .ok,
      body: jsonData,
      headers: ["Content-Type": "application/json"]
    )

    // When
    let result =
      try response
      .chain()
      .validate(.successStatus)
      .validate(.json)
      .decode(JSONDecoderTransformer(TestUser.self))
      .cache(for: .minutes(5))

    // Then
    XCTAssertEqual(result.value, user)
    XCTAssertTrue(result.isCacheValid)
    XCTAssertEqual(result.response.status.rawValue, 200)
  }

  func testMapTransformation() throws {
    // Given
    let testString = "hello world"
    let response = createMockResponse(body: testString.data(using: .utf8))

    // When
    let transformedResponse =
      try response
      .chain()
      .decode(StringTransformer())
      .map { $0.uppercased() }

    // Then
    XCTAssertEqual(transformedResponse.extractValue(), "HELLO WORLD")
  }

  func testCacheDurationFactory() {
    // When
    let seconds = ResponseCacheDuration.seconds(30)
    let minutes = ResponseCacheDuration.minutes(5)
    let hours = ResponseCacheDuration.hours(2)
    let days = ResponseCacheDuration.days(1)

    // Then
    XCTAssertEqual(seconds.seconds, 30)
    XCTAssertEqual(minutes.seconds, 300)  // 5 * 60
    XCTAssertEqual(hours.seconds, 7200)  // 2 * 3600
    XCTAssertEqual(days.seconds, 86_400)  // 1 * 86400
  }

  func testValidationFailure() {
    // Given
    let response = createMockResponse(status: .internalServerError)

    // When & Then
    XCTAssertThrowsError(try response.chain().validateSuccess()) { error in
      guard let httpError = error as? HTTPError else {
        XCTFail("Expected HTTPError")
        return
      }

      switch httpError.category {
      case .http(let status):
        XCTAssertEqual(status.rawValue, 500)

      default:
        XCTFail("Expected HTTP error category")
      }
    }
  }

  func testEmptyBodyDecoding() {
    // Given
    let response = createMockResponse(body: nil)

    // When & Then
    XCTAssertThrowsError(try response.chain().decode(JSONDecoderTransformer(TestUser.self))) {
      error in
      guard let httpError = error as? HTTPError else {
        XCTFail("Expected HTTPError")
        return
      }

      switch httpError.category {
      case .decoding(let message):
        XCTAssertTrue(message.contains("empty"))

      default:
        XCTFail("Expected decoding error category")
      }
    }
  }
}
