import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite("Network traffic recorder")
struct NetworkTrafficRecorderTests {
  @Test("Records a completed request while protecting values by default")
  // swiftlint:disable:next function_body_length
  func recordsSafeMetadataByDefault() async throws {
    let contextID = MockContextIdentifier()
    let url = try #require(URL(string: "https://example.com/items?token=secret&limit=10"))
    let requestURL = HTTPRequestURL(url)
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }
    MockURLProtocol.stub(
      matching: .url(requestURL),
      response: .success(
        statusCode: 201,
        data: HTTPBody(Data("response-secret".utf8)),
        headers: ["X-Request-ID": "private-response-value"]
      ),
      contextID: contextID
    )

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }
    let recorder = NetworkTrafficRecorder(capacity: 10)
    let client = NetworkClient(session: session, trafficRecorder: recorder)
    let request = HTTPRequest(
      method: .post,
      url: requestURL,
      headers: ["Authorization": "Bearer secret", "X-Trace": "private-request-value"],
      body: HTTPBody(Data("request-secret".utf8))
    )

    _ = try await client.execute(request)

    let records = await recorder.records()
    let record = try #require(records.first)
    let recordedURL = try #require(record.request.url)
    let queryItems = URLComponents(url: recordedURL, resolvingAgainstBaseURL: false)?
      .queryItems

    #expect(records.count == 1)
    #expect(record.sequence == 0)
    #expect(record.requestID == request.id)
    #expect(record.request.method == "POST")
    #expect(queryItems?.map(\.name) == ["token", "limit"])
    #expect(queryItems?.allSatisfy { $0.value == nil } == true)
    #expect(record.request.headerNames == ["Authorization", "X-Trace"])
    #expect(record.request.headers.isEmpty)
    #expect(record.request.body == nil)
    #expect(record.response?.statusCode == 201)
    #expect(record.response?.headerNames == ["X-Request-ID"])
    #expect(record.response?.headers.isEmpty == true)
    #expect(record.response?.body == nil)
    #expect(record.failure == nil)
    #expect(record.endedAt >= record.startedAt)
  }

  @Test("Opt-in values are bounded and recorder retention stays within capacity")
  // swiftlint:disable:next function_body_length
  func boundsCapturedValuesAndHistory() async throws {
    let contextID = MockContextIdentifier()
    let url = try #require(URL(string: "https://example.com/upload?token=visible"))
    let requestURL = HTTPRequestURL(url)
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }
    MockURLProtocol.stubSequential(
      url: requestURL,
      responses: [
        .success(
          statusCode: 200,
          data: HTTPBody(Data("response-one".utf8)),
          headers: ["X-Debug": "first"]
        ),
        .success(
          statusCode: 200,
          data: HTTPBody(Data("response-two".utf8)),
          headers: ["X-Debug": "second"]
        ),
        .success(
          statusCode: 200,
          data: HTTPBody(Data("response-three".utf8)),
          headers: ["X-Debug": "third"]
        ),
      ],
      contextID: contextID
    )

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }
    let recorder = NetworkTrafficRecorder(
      capacity: 2,
      capturePolicy: NetworkTrafficCapturePolicy(
        includesQueryValues: true,
        capturedHeaderNames: ["x-debug"],
        bodyByteLimit: 5
      )
    )
    let client = NetworkClient(session: session, trafficRecorder: recorder)
    let request = HTTPRequest(
      method: .post,
      url: requestURL,
      headers: ["X-Debug": "request-value", "Authorization": "still-private"],
      body: HTTPBody(Data("request-secret".utf8))
    )

    for _ in 0..<3 {
      _ = try await client.execute(request)
    }

    let records = await recorder.records()
    let lastRecord = try #require(records.last)

    #expect(records.map(\.sequence) == [1, 2])
    #expect(lastRecord.request.url?.query == "token=visible")
    #expect(lastRecord.request.headers == ["X-Debug": "request-value"])
    #expect(lastRecord.request.body?.data == Data("reque".utf8))
    #expect(lastRecord.request.body?.originalByteCount == 14)
    #expect(lastRecord.request.body?.isTruncated == true)
    #expect(lastRecord.response?.headers == ["X-Debug": "third"])
    #expect(lastRecord.response?.body?.data == Data("respo".utf8))
    #expect(lastRecord.response?.body?.originalByteCount == 14)
    #expect(lastRecord.response?.body?.isTruncated == true)
  }

  @Test("Records transport failures without retaining the error description")
  func recordsTransportFailure() async throws {
    let contextID = MockContextIdentifier()
    let url = HTTPRequestURL(try #require(URL(string: "https://example.com/failure")))
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }
    MockURLProtocol.stub(
      matching: .url(url),
      response: .failure(URLError(.timedOut)),
      contextID: contextID
    )

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }
    let recorder = NetworkTrafficRecorder()
    let client = NetworkClient(session: session, trafficRecorder: recorder)

    await #expect(throws: HTTPError.self) {
      _ = try await client.execute(HTTPRequest(method: .get, url: url))
    }

    let records = await recorder.records()
    let record = try #require(records.first)
    #expect(record.response == nil)
    #expect(record.failure?.domain == URLError.errorDomain)
    #expect(record.failure?.code == URLError.timedOut.rawValue)
  }

  @Test("Records a non-HTTP response together with the framework failure")
  func recordsInvalidResponseFailure() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [NonHTTPResponseURLProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let recorder = NetworkTrafficRecorder()
    let client = NetworkClient(session: session, trafficRecorder: recorder)
    let url = HTTPRequestURL(try #require(URL(string: "custom-response://example/resource")))

    await #expect(throws: HTTPError.self) {
      _ = try await client.execute(HTTPRequest(method: .get, url: url))
    }

    let record = try #require(await recorder.records().first)
    #expect(record.response?.statusCode == nil)
    #expect(record.failure != nil)
  }

}

private final class NonHTTPResponseURLProtocol: URLProtocol, @unchecked Sendable {
  override static func canInit(with request: URLRequest) -> Bool {
    request.url?.scheme == "custom-response"
  }

  override static func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    guard let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }
    let response = URLResponse(
      url: url,
      mimeType: "application/octet-stream",
      expectedContentLength: 0,
      textEncodingName: nil
    )
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}
