@testable import NetworkingInterceptorsCompat
import NetworkingRuntime
import NetworkingDSL
import NetworkingTesting
import XCTest

// swiftlint:disable file_length

final class InterceptorChainTests: XCTestCase {  // swiftlint:disable:this type_body_length
  // MARK: - Mock Interceptors

  struct MockRequestInterceptor: RequestInterceptor {
    let name: String
    let result: InterceptorResult
    let onIntercept: (@Sendable (inout HTTPRequest, InterceptorContext) -> Void)?

    init(
      name: String,
      result: InterceptorResult = .proceed,
      onIntercept: (@Sendable (inout HTTPRequest, InterceptorContext) -> Void)? = nil
    ) {
      self.name = name
      self.result = result
      self.onIntercept = onIntercept
    }

    func intercept(
      request: inout HTTPRequest,
      context: InterceptorContext
    ) async throws -> InterceptorResult {
      onIntercept?(&request, context)
      return result
    }
  }

  struct MockResponseInterceptor: ResponseInterceptor {
    let name: String
    let result: InterceptorResult
    let onIntercept: (@Sendable (HTTPResponse, InterceptorContext) -> Void)?

    init(
      name: String,
      result: InterceptorResult = .proceed,
      onIntercept: (@Sendable (HTTPResponse, InterceptorContext) -> Void)? = nil
    ) {
      self.name = name
      self.result = result
      self.onIntercept = onIntercept
    }

    func intercept(
      response: HTTPResponse,
      context: InterceptorContext
    ) async throws -> InterceptorResult {
      onIntercept?(response, context)
      return result
    }
  }

  struct ThrowingRequestInterceptor: RequestInterceptor {
    let error: Error

    func intercept(
      request _: inout HTTPRequest,
      context _: InterceptorContext
    ) async throws -> InterceptorResult {
      throw error
    }
  }

  struct ThrowingResponseInterceptor: ResponseInterceptor {
    let error: Error

    func intercept(
      response _: HTTPResponse,
      context _: InterceptorContext
    ) async throws -> InterceptorResult {
      throw error
    }
  }

  // MARK: - Helper Methods

  func makeRequest() -> HTTPRequest {
    HTTPRequest(
      method: .get,
      url: URL(string: "https://api.example.com/users")!
    )
  }

  func makeResponse() -> HTTPResponse {
    HTTPResponse(
      request: makeRequest(),
      status: HTTPStatus(rawValue: 200),
      body: Data()
    )
  }

  func makeContext() -> InterceptorContext {
    InterceptorContext(path: "/users", method: .get, attemptCount: 0)
  }

  // MARK: - Empty Chain Tests

  func testEmptyChain() {
    let chain = InterceptorChain()

    XCTAssertTrue(chain.isEmpty.rawValue)
    XCTAssertFalse(chain.hasRequestInterceptors.rawValue)
    XCTAssertFalse(chain.hasResponseInterceptors.rawValue)
  }

  func testEmptyRequestInterceptorChain() async throws {
    let chain = InterceptorChain()
    var request = makeRequest()
    let context = makeContext()

    let result = try await chain.executeRequestInterceptors(request: &request, context: context)

    if case .proceed = result {
      // Expected
    } else {
      XCTFail("Empty chain should return .proceed")
    }
  }

  func testEmptyResponseInterceptorChain() async throws {
    let chain = InterceptorChain()
    let response = makeResponse()
    let context = makeContext()

    let result = try await chain.executeResponseInterceptors(response: response, context: context)

    if case .proceed = result {
      // Expected
    } else {
      XCTFail("Empty chain should return .proceed")
    }
  }

  // MARK: - Sequential Execution Tests

  func testRequestInterceptorsExecuteInOrder() async throws {
    nonisolated(unsafe) var executionOrder: [String] = []

    let interceptor1 = MockRequestInterceptor(name: "first") { _, _ in
      executionOrder.append("first")
    }
    let interceptor2 = MockRequestInterceptor(name: "second") { _, _ in
      executionOrder.append("second")
    }
    let interceptor3 = MockRequestInterceptor(name: "third") { _, _ in
      executionOrder.append("third")
    }

    let chain = InterceptorChain(
      requestInterceptors: [interceptor1, interceptor2, interceptor3]
    )

    var request = makeRequest()
    let context = makeContext()

    _ = try await chain.executeRequestInterceptors(request: &request, context: context)

    XCTAssertEqual(executionOrder, ["first", "second", "third"])
  }

  func testResponseInterceptorsExecuteInOrder() async throws {
    nonisolated(unsafe) var executionOrder: [String] = []

    let interceptor1 = MockResponseInterceptor(name: "first") { _, _ in
      executionOrder.append("first")
    }
    let interceptor2 = MockResponseInterceptor(name: "second") { _, _ in
      executionOrder.append("second")
    }
    let interceptor3 = MockResponseInterceptor(name: "third") { _, _ in
      executionOrder.append("third")
    }

    let chain = InterceptorChain(
      responseInterceptors: [interceptor1, interceptor2, interceptor3]
    )

    let response = makeResponse()
    let context = makeContext()

    _ = try await chain.executeResponseInterceptors(response: response, context: context)

    XCTAssertEqual(executionOrder, ["first", "second", "third"])
  }

  // MARK: - Request Modification Tests

  func testRequestInterceptorsCanModifyRequest() async throws {
    let authInterceptor = MockRequestInterceptor(name: "auth") { request, _ in
      request = HTTPRequest(
        method: request.method,
        url: request.url,
        headers: request.headers.merging(["Authorization": "Bearer token"]) { _, new in new },
        body: request.body,
        timeout: request.timeout
      )
    }

    let chain = InterceptorChain(requestInterceptors: [authInterceptor])

    var request = makeRequest()
    let context = makeContext()

    _ = try await chain.executeRequestInterceptors(request: &request, context: context)

    XCTAssertEqual(request.headers["Authorization"], "Bearer token")
  }

  // MARK: - Short-Circuit Tests

  func testRequestInterceptorShortCircuit() async throws {
    let cachedResponse = HTTPResponse(
      request: makeRequest(),
      status: HTTPStatus(rawValue: 200),
      body: Data("cached".utf8)
    )

    let cacheInterceptor = MockRequestInterceptor(
      name: "cache",
      result: .shortCircuit(cachedResponse)
    )

    nonisolated(unsafe) var executedAfterCache = false
    let nextInterceptor = MockRequestInterceptor(name: "next") { _, _ in
      executedAfterCache = true
    }

    let chain = InterceptorChain(
      requestInterceptors: [cacheInterceptor, nextInterceptor]
    )

    var request = makeRequest()
    let context = makeContext()

    let result = try await chain.executeRequestInterceptors(request: &request, context: context)

    // Verify short-circuit was returned
    if case .shortCircuit(let response) = result {
      XCTAssertEqual(
        String(data: (response.body ?? HTTPBody(Data())).rawValue, encoding: .utf8),
        "cached"
      )
    } else {
      XCTFail("Expected .shortCircuit result")
    }

    // Verify execution stopped after short-circuit
    XCTAssertFalse(executedAfterCache)
  }

  // MARK: - Retry Tests

  func testResponseInterceptorRetry() async throws {
    let retryInterceptor = MockResponseInterceptor(
      name: "retry",
      result: .retry(after: nil)
    )

    nonisolated(unsafe) var executedAfterRetry = false
    let nextInterceptor = MockResponseInterceptor(name: "next") { _, _ in
      executedAfterRetry = true
    }

    let chain = InterceptorChain(
      responseInterceptors: [retryInterceptor, nextInterceptor]
    )

    let response = makeResponse()
    let context = makeContext()

    let result = try await chain.executeResponseInterceptors(response: response, context: context)

    // Verify retry was returned
    if case .retry = result {
      // Expected
    } else {
      XCTFail("Expected .retry result")
    }

    // Verify execution stopped after retry
    XCTAssertFalse(executedAfterRetry)
  }

  func testResponseInterceptorRetryWithDelay() async throws {
    let delay = 5.0
    let retryInterceptor = MockResponseInterceptor(
      name: "retry",
      result: .retry(after: RetryDelay(delay))
    )

    let chain = InterceptorChain(responseInterceptors: [retryInterceptor])

    let response = makeResponse()
    let context = makeContext()

    let result = try await chain.executeResponseInterceptors(response: response, context: context)

    if case .retry(let afterDelay) = result {
      XCTAssertEqual(afterDelay, RetryDelay(delay))
    } else {
      XCTFail("Expected .retry result with delay")
    }
  }

  // MARK: - Error Propagation Tests

  func testRequestInterceptorErrorWrapped() async throws {
    struct TestError: Error {}
    let throwingInterceptor = ThrowingRequestInterceptor(error: TestError())

    let chain = InterceptorChain(requestInterceptors: [throwingInterceptor])

    var request = makeRequest()
    let context = makeContext()

    do {
      _ = try await chain.executeRequestInterceptors(request: &request, context: context)
      XCTFail("Expected error to be thrown")
    } catch let error as InterceptorError {
      if case .interceptorFailed(let underlyingError) = error {
        XCTAssertTrue(underlyingError is TestError)
      } else {
        XCTFail("Expected .interceptorFailed error")
      }
    }
  }

  func testResponseInterceptorErrorWrapped() async throws {
    struct TestError: Error {}
    let throwingInterceptor = ThrowingResponseInterceptor(error: TestError())

    let chain = InterceptorChain(responseInterceptors: [throwingInterceptor])

    let response = makeResponse()
    let context = makeContext()

    do {
      _ = try await chain.executeResponseInterceptors(response: response, context: context)
      XCTFail("Expected error to be thrown")
    } catch let error as InterceptorError {
      if case .interceptorFailed(let underlyingError) = error {
        XCTAssertTrue(underlyingError is TestError)
      } else {
        XCTFail("Expected .interceptorFailed error")
      }
    }
  }

  func testErrorStopsChainExecution() async throws {
    struct TestError: Error {}
    let throwingInterceptor = ThrowingRequestInterceptor(error: TestError())

    nonisolated(unsafe) var executedAfterError = false
    let nextInterceptor = MockRequestInterceptor(name: "next") { _, _ in
      executedAfterError = true
    }

    let chain = InterceptorChain(
      requestInterceptors: [throwingInterceptor, nextInterceptor]
    )

    var request = makeRequest()
    let context = makeContext()

    do {
      _ = try await chain.executeRequestInterceptors(request: &request, context: context)
      XCTFail("Expected error to be thrown")
    } catch {
      // Expected
    }

    XCTAssertFalse(executedAfterError)
  }

  // MARK: - Context Tests

  func testContextPassedToInterceptors() async throws {
    nonisolated(unsafe) var receivedContext: InterceptorContext?

    let interceptor = MockRequestInterceptor(name: "test") { _, context in
      receivedContext = context
    }

    let chain = InterceptorChain(requestInterceptors: [interceptor])

    var request = makeRequest()
    let originalContext = InterceptorContext(
      path: "/test/path",
      method: .post,
      attemptCount: 2,
      metadata: ["key": .string("value")]
    )

    _ = try await chain.executeRequestInterceptors(request: &request, context: originalContext)

    XCTAssertEqual(receivedContext?.path.rawValue, "/test/path")
    XCTAssertEqual(receivedContext?.method.rawValue, "POST")
    XCTAssertEqual(receivedContext?.attemptCount.rawValue, 2)
    XCTAssertEqual(
      receivedContext?.metadata[InterceptorMetadataKey("key")]?.stringValue?.rawValue,
      "value"
    )
  }

  // MARK: - Convenience Properties Tests

  func testHasRequestInterceptors() {
    let emptyChain = InterceptorChain()
    XCTAssertFalse(emptyChain.hasRequestInterceptors.rawValue)

    let chainWithRequest = InterceptorChain(
      requestInterceptors: [MockRequestInterceptor(name: "test")]
    )
    XCTAssertTrue(chainWithRequest.hasRequestInterceptors.rawValue)
  }

  func testHasResponseInterceptors() {
    let emptyChain = InterceptorChain()
    XCTAssertFalse(emptyChain.hasResponseInterceptors.rawValue)

    let chainWithResponse = InterceptorChain(
      responseInterceptors: [MockResponseInterceptor(name: "test")]
    )
    XCTAssertTrue(chainWithResponse.hasResponseInterceptors.rawValue)
  }

  func testIsEmpty() {
    let emptyChain = InterceptorChain()
    XCTAssertTrue(emptyChain.isEmpty.rawValue)

    let chainWithRequest = InterceptorChain(
      requestInterceptors: [MockRequestInterceptor(name: "test")]
    )
    XCTAssertFalse(chainWithRequest.isEmpty.rawValue)

    let chainWithResponse = InterceptorChain(
      responseInterceptors: [MockResponseInterceptor(name: "test")]
    )
    XCTAssertFalse(chainWithResponse.isEmpty.rawValue)

    let chainWithBoth = InterceptorChain(
      requestInterceptors: [MockRequestInterceptor(name: "test")],
      responseInterceptors: [MockResponseInterceptor(name: "test")]
    )
    XCTAssertFalse(chainWithBoth.isEmpty.rawValue)
  }
}
