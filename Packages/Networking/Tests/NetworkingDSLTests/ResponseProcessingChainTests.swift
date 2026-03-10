// swiftlint:disable file_length
import Foundation
@testable import NetworkingDSL
import NetworkingRuntime
import NetworkingRuntimeDSL
import NetworkingTesting
import XCTest

// swiftlint:disable:next type_body_length
final class ResponseProcessingChainTests: XCTestCase {
  // MARK: - Test Data

  private struct TestUser: Codable, Sendable, Equatable {
    let id: Int
    let name: String
    let email: String
  }

  private struct TestError: Codable, Sendable {
    let code: String
    let message: String
  }

  private func createMockRequest() -> HTTPRequest {
    HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users/1")!,
      headers: [:],
      body: nil,
      timeout: 30.0
    )
  }

  private func createMockResponse(
    status: HTTPStatus = .ok,
    headers: [String: String] = ["Content-Type": "application/json"],
    body: Data? = nil
  ) -> HTTPResponse {
    HTTPResponse(
      request: createMockRequest(),
      status: status,
      headers: headers,
      body: body
    )
  }

  private func createJSONData<T: Codable>(_ object: T) throws -> Data {
    try JSONEncoder().encode(object)
  }

  // MARK: - Basic Chain Tests

  func testBasicResponseChain() throws {
    // Given
    let response = createMockResponse()

    // When
    let chain = response.chain()

    // Then
    XCTAssertEqual(chain.response.status, .ok)
    XCTAssertEqual(chain.value.status, .ok)
  }

  func testChainValidation() throws {
    // Given
    let response = createMockResponse(status: .ok)

    // When & Then
    XCTAssertNoThrow(try response.chain().validate(StatusValidator.successStatus))
  }

  func testChainValidationFailure() throws {
    // Given
    let response = createMockResponse(status: .badRequest)

    // When & Then
    XCTAssertThrowsError(try response.chain().validate(StatusValidator.successStatus)) {
      error in
      XCTAssertTrue(error is HTTPError)
    }
  }

  func testChainSuccessValidation() throws {
    // Given
    let response = createMockResponse(status: .ok)

    // When
    let validatedResponse = try response.chain().validateSuccess()

    // Then
    XCTAssertEqual(validatedResponse.response.status, .ok)
    XCTAssertEqual(validatedResponse.value.status, .ok)
  }

  // MARK: - JSON Decoding Chain Tests

  func testJSONDecodingChain() throws {
    // Given
    let user = TestUser(id: 1, name: "John Doe", email: "john@example.com")
    let jsonData = try createJSONData(user)
    let response = createMockResponse(body: jsonData)

    // When
    let decodedResponse = try response.chain().decode(JSONDecoderTransformer(TestUser.self))

    // Then
    XCTAssertEqual(decodedResponse.value, user)
    XCTAssertEqual(decodedResponse.response.status, .ok)
  }

  func testJSONDecodingChainWithCustomDecoder() throws {
    // Given
    let user = TestUser(id: 1, name: "John Doe", email: "john@example.com")
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let jsonData = try createJSONData(user)
    let response = createMockResponse(body: jsonData)

    // When
    let decodedResponse = try response.chain().decode(
      JSONDecoderTransformer(TestUser.self, decoder: decoder)
    )

    // Then
    XCTAssertEqual(decodedResponse.value, user)
  }

  func testJSONDecodingChainFailure() throws {
    // Given
    let invalidJSON = Data("invalid json".utf8)
    let response = createMockResponse(body: invalidJSON)

    // When & Then
    XCTAssertThrowsError(try response.chain().decode(JSONDecoderTransformer(TestUser.self))) {
      error in
      XCTAssertTrue(error is HTTPError)
      if let httpError = error as? HTTPError {
        if case .decoding = httpError.category {
          XCTAssertTrue(true)  // Expected decoding error
        } else {
          XCTFail("Expected decoding error")
        }
      }
    }
  }

  func testJSONDecodingChainEmptyBody() throws {
    // Given
    let response = createMockResponse(body: nil)

    // When & Then
    XCTAssertThrowsError(try response.chain().decode(JSONDecoderTransformer(TestUser.self))) {
      error in
      XCTAssertTrue(error is HTTPError)
      if let httpError = error as? HTTPError {
        if case .decoding = httpError.category {
          XCTAssertTrue(true)  // Expected empty body decoding error
        } else {
          XCTFail("Expected decoding error for empty body")
        }
      }
    }
  }

  // MARK: - String Transformation Chain Tests

  func testStringTransformationChain() throws {
    // Given
    let testString = "Hello, World!"
    let stringData = Data(testString.utf8)
    let response = createMockResponse(body: stringData)

    // When
    let stringResponse = try response.chain().asString()

    // Then
    XCTAssertEqual(stringResponse.value.rawValue, testString)
    XCTAssertEqual(stringResponse.response.status, .ok)
  }

  func testStringTransformationChainWithEncoding() throws {
    // Given
    let testString = "Hello, World!"
    let stringData = testString.data(using: .utf16)!
    let response = createMockResponse(body: stringData)

    // When
    let stringResponse = try response.chain().asString(encoding: .utf16)

    // Then
    XCTAssertEqual(stringResponse.value.rawValue, testString)
  }

  func testStringTransformationChainFailure() throws {
    // Given
    let invalidData = Data([0xFF, 0xFE, 0xFF, 0xFF])  // Invalid UTF-8
    let response = createMockResponse(body: invalidData)

    // When & Then
    XCTAssertThrowsError(try response.chain().asString()) { error in
      XCTAssertTrue(error is HTTPError)
    }
  }

  // MARK: - Custom Transformation Chain Tests

  func testCustomTransformationChain() throws {
    // Given
    let response = createMockResponse()

    // When
    let transformedResponse = try response.chain().transform(MockTransformer())

    // Then
    XCTAssertEqual(transformedResponse.value, "Transformed: OK")
  }

  func testMapTransformationChain() throws {
    // Given
    let response = createMockResponse()

    // When
    let mappedResponse = try response.chain().map { httpResponse in
      "Status: \(httpResponse.status.rawValue)"
    }

    // Then
    XCTAssertEqual(mappedResponse.value, "Status: 200")
  }

  // MARK: - Cache Chain Tests

  func testCacheChain() throws {
    // Given
    let response = createMockResponse()

    // When
    let cachedResponse = response.chain().cache(for: .minutes(5))

    // Then
    XCTAssertTrue(cachedResponse.isCacheValid.rawValue)
    XCTAssertEqual(cachedResponse.value.status, .ok)
    XCTAssertEqual(cachedResponse.response.status, .ok)
  }

  // MARK: - Complex Chain Tests

  func testComplexValidationAndDecodingChain() throws {
    // Given
    let user = TestUser(id: 1, name: "John Doe", email: "john@example.com")
    let jsonData = try createJSONData(user)
    let response = createMockResponse(body: jsonData)

    // When
    let result =
      try response
      .chain()
      .validate(StatusValidator.successStatus)
      .validate(ContentTypeValidator.json())
      .decode(JSONDecoderTransformer(TestUser.self))

    // Then
    XCTAssertEqual(result.value, user)
  }

  func testComplexChainWithTransformation() throws {
    // Given
    let user = TestUser(id: 1, name: "John Doe", email: "john@example.com")
    let jsonData = try createJSONData(user)
    let response = createMockResponse(body: jsonData)

    // When
    let result =
      try response
      .chain()
      .decode(JSONDecoderTransformer(TestUser.self))
      .map { user in
        "User: \(user.name) (\(user.email))"
      }
      .validateSuccess()

    // Then
    XCTAssertEqual(result.value, "User: John Doe (john@example.com)")
  }

  func testChainWithCacheAndTransformation() throws {
    // Given
    let testString = "Hello, World!"
    let stringData = Data(testString.utf8)
    let response = createMockResponse(body: stringData)

    // When
    let result =
      try response
      .chain()
      .decode(StringTransformer())
      .map { $0.uppercased() }
      .cache(for: ResponseCacheDuration.hours(1))

    // Then
    XCTAssertEqual(result.value, "HELLO, WORLD!")
    XCTAssertTrue(result.isCacheValid.rawValue)
  }

  // MARK: - Error Recovery Chain Tests

  func testErrorRecoveryChain() throws {
    // Given
    let response = createMockResponse(status: .badRequest)

    // When
    let recoveredResult: ResponseChain<String>
    do {
      recoveredResult =
        try response
        .chain()
        .validate(StatusValidator.successStatus)
        .map { _ in "Should not reach here" }
    } catch {
      // Recovery: return a default chain
      recoveredResult = try response.chain().map { _ in "Recovered from error" }
    }

    // Then
    XCTAssertEqual(recoveredResult.value, "Recovered from error")
  }

  func testErrorRecoveryChainRethrowsOnRecoveryFailure() throws {
    // Given
    let response = createMockResponse(status: .badRequest)

    // When & Then
    XCTAssertThrowsError(
      try {
        do {
          _ = try response.chain().validate(StatusValidator.successStatus)
        } catch {
          // Recovery also fails
          throw HTTPError(category: .configuration("Recovery failed"))
        }
      }()
    ) { error in
      XCTAssertTrue(error is HTTPError)
      if let httpError = error as? HTTPError {
        if case .configuration(let message) = httpError.category {
          XCTAssertTrue(message.contains("Recovery failed"))
        } else {
          XCTFail("Expected configuration error")
        }
      }
    }
  }

  // MARK: - HTTPResponseBuilder Tests

  func testHTTPResponseBuilderBasicProcessing() throws {
    // Given
    let user = TestUser(id: 1, name: "John Doe", email: "john@example.com")
    let jsonData = try createJSONData(user)
    let response = createMockResponse(body: jsonData)

    // When
    let result: HTTPResponseBuilder.ProcessedResponse<TestUser> = try response.process {
      ValidateStatus.success
      DecodeJSON(TestUser.self)
    }

    // Then
    XCTAssertEqual(result.value, user)
    XCTAssertEqual(result.response.status, .ok)
  }

  func testHTTPResponseBuilderWithValidation() throws {
    // Given
    let response = createMockResponse()

    // When & Then
    XCTAssertNoThrow(
      try {
        let result: HTTPResponseBuilder.ProcessedResponse<HTTPResponse> =
          try response.process {
            ValidateStatus.success
            ValidateContentType.json
            MapValue<HTTPResponse, HTTPResponse> { $0 }
          }
        XCTAssertEqual(result.value.status, .ok)
      }()
    )
  }

  func testHTTPResponseBuilderWithStringTransformation() throws {
    // Given
    let testString = "Hello, World!"
    let stringData = testString.data(using: .utf8)!
    let response = createMockResponse(body: stringData)

    // When
    let result: HTTPResponseBuilder.ProcessedResponse<HTTPResponseText> = try response.process {
      ValidateStatus.success
      TransformToString()
    }

    // Then
    XCTAssertEqual(result.value.rawValue, testString)
  }

  func testHTTPResponseBuilderWithCache() throws {
    // Given
    let response = createMockResponse()

    // When
    let result: HTTPResponseBuilder.ProcessedResponse<HTTPResponse> = try response.process {
      ValidateStatus.success
      CacheFor.minutes(5)
      MapValue<HTTPResponse, HTTPResponse> { $0 }
    }

    // Then
    XCTAssertEqual(result.value.status, .ok)
  }

  func testHTTPResponseBuilderWithErrorRecovery() throws {
    // Given
    let response = createMockResponse(status: .badRequest)

    // When
    let result: HTTPResponseBuilder.ProcessedResponse<String> = try response.process {
      ValidateStatus.success
      RecoverWith<String> { _ in "Recovered" }
    }

    // Then
    XCTAssertEqual(result.value, "Recovered")
  }

  // MARK: - Async Transformation Chain Tests

  func testAsyncTransformationChain() async throws {
    // Given
    let user = TestUser(id: 1, name: "John Doe", email: "john@example.com")
    let jsonData = try createJSONData(user)
    let response = createMockResponse(body: jsonData)

    // When
    let result =
      try await response
      .asyncChain()
      .map { $0.body! }
      .transform(AsyncJSONDecoderTransformer(TestUser.self))

    // Then
    XCTAssertEqual(result.value, user)
  }

  func testAsyncChainWithMapping() async throws {
    // Given
    let response = createMockResponse()

    // When
    let result =
      try await response
      .asyncChain()
      .map { httpResponse in
        "Async Status: \(httpResponse.status.rawValue)"
      }

    // Then
    XCTAssertEqual(result.value, "Async Status: 200")
  }

  // MARK: - Performance Tests

  func testChainPerformance() throws {
    // Given
    let user = TestUser(id: 1, name: "John Doe", email: "john@example.com")
    let jsonData = try createJSONData(user)
    let response = createMockResponse(body: jsonData)

    // When & Then
    measure {
      for _ in 0..<1000 {
        do {
          _ =
            try response
            .chain()
            .decode(JSONDecoderTransformer(TestUser.self))
            .validateSuccess()
            .map { "User: \($0.name)" }
        } catch {
          XCTFail("Chain processing failed: \(error)")
        }
      }
    }
  }

  // MARK: - Edge Cases

  func testChainWithNilBody() throws {
    // Given
    let response = createMockResponse(body: nil)

    // When & Then
    XCTAssertThrowsError(try response.chain().decode(JSONDecoderTransformer(TestUser.self)))
    XCTAssertThrowsError(try response.chain().asString())
  }

  func testChainWithEmptyBody() throws {
    // Given
    let response = createMockResponse(body: Data())

    // When & Then
    XCTAssertThrowsError(try response.chain().decode(JSONDecoderTransformer(TestUser.self)))
    XCTAssertNoThrow(try response.chain().asString())  // Empty string is valid
  }

  func testChainResultExtraction() throws {
    // Given
    let response = createMockResponse()

    // When
    let chain = response.chain()
    let result = chain.result()
    let value = chain.extractValue()

    // Then
    XCTAssertEqual(result.response.status, .ok)
    XCTAssertEqual(result.value.status, .ok)
    XCTAssertEqual(value.status, .ok)
  }
}

// MARK: - Mock Transformer

private struct MockTransformer: ResponseTransformer {
  typealias Input = HTTPResponse
  typealias Output = String

  func transform(_ input: HTTPResponse) throws -> String {
    "Transformed: \(input.status.description)"
  }
}

// MARK: - Test Extensions

extension HTTPStatus {
  var description: String {
    switch self {
    case .ok:
      return "OK"

    case .badRequest:
      return "Bad Request"

    default:
      return "Status \(rawValue)"
    }
  }
}
