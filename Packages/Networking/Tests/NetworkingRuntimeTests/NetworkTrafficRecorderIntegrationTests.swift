import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite("Network traffic recorder integration")
struct NetworkTrafficRecorderIntegrationTests {
  @Test("Builder retries create one ordered record per physical attempt")
  func recordsEveryRetryAttempt() async throws {
    let contextID = MockContextIdentifier()
    let url = HTTPRequestURL(try #require(URL(string: "https://example.com/retry")))
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }
    MockURLProtocol.stubSequential(
      url: url,
      responses: [
        .success(statusCode: 500, data: HTTPBody(Data("failure".utf8))),
        .success(statusCode: 200, data: HTTPBody(Data("success".utf8))),
      ],
      contextID: contextID
    )

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }
    let recorder = NetworkTrafficRecorder()
    let client = try NetworkClient {
      CustomSession(session)
      EnableTrafficDebugging(recorder)
      EnableRetry(
        RetryMiddleware.Configuration(
          maxAttempts: 1,
          baseDelay: 0,
          jitterStrategy: .none
        )
      )
    }
    let request = HTTPRequest(method: .get, url: url)

    _ = try await client.execute(request)

    let records = await recorder.records()
    #expect(records.map(\.sequence) == [0, 1])
    #expect(records.map(\.requestID) == [request.id, request.id])
    #expect(records.compactMap { $0.response?.statusCode } == [500, 200])
    #expect(records.allSatisfy { $0.failure == nil })
  }

  @Test("Preserves task metrics callbacks on an injected session delegate")
  func forwardsMetricsToSessionTaskDelegate() async throws {
    let contextID = MockContextIdentifier()
    let url = HTTPRequestURL(try #require(URL(string: "https://example.com/metrics")))
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }
    MockURLProtocol.stubSuccess(url: url, contextID: contextID)

    let originalDelegate = MetricsTaskDelegate()
    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID),
      delegate: originalDelegate,
      delegateQueue: nil
    )
    defer { session.invalidateAndCancel() }
    let recorder = NetworkTrafficRecorder()
    let client = NetworkClient(session: session, trafficRecorder: recorder)

    _ = try await client.execute(HTTPRequest(method: .get, url: url))

    #expect(originalDelegate.metricsCallbackCount() == 1)
  }

  @Test("Preserves task authentication handling on an injected session delegate")
  func forwardsAuthenticationChallengeToSessionTaskDelegate() async throws {
    let originalDelegate = AuthenticationTaskDelegate()
    let session = URLSession(
      configuration: .ephemeral,
      delegate: originalDelegate,
      delegateQueue: nil
    )
    defer { session.invalidateAndCancel() }
    let url = try #require(URL(string: "https://example.com/protected"))
    let task = session.dataTask(with: url)
    let delegate = NetworkTrafficTaskDelegate(
      policy: .metadataOnly,
      forwardingTo: originalDelegate
    )
    let protectionSpace = URLProtectionSpace(
      host: "example.com",
      port: 443,
      protocol: "https",
      realm: "test",
      authenticationMethod: NSURLAuthenticationMethodHTTPBasic
    )
    let challenge = URLAuthenticationChallenge(
      protectionSpace: protectionSpace,
      proposedCredential: nil,
      previousFailureCount: 0,
      failureResponse: nil,
      error: nil,
      sender: AuthenticationChallengeSender()
    )

    let disposition = await withCheckedContinuation { continuation in
      delegate.urlSession(
        session,
        task: task,
        didReceive: challenge
      ) { disposition, _ in
        continuation.resume(returning: disposition)
      }
    }

    #expect(disposition == .cancelAuthenticationChallenge)
    #expect(originalDelegate.challengeCount() == 1)
  }

  @Test("Concurrent attempts stay ordered by physical start rather than completion")
  func ordersConcurrentAttemptsByStart() async throws {
    let contextID = MockContextIdentifier()
    let slowURL = HTTPRequestURL(try #require(URL(string: "https://example.com/slow")))
    let fastURL = HTTPRequestURL(try #require(URL(string: "https://example.com/fast")))
    MockURLProtocol.clearAll(contextID: contextID)
    defer { MockURLProtocol.clearAll(contextID: contextID) }
    let slowStart = AsyncStream.makeStream(of: Int.self)
    MockURLProtocol.stub(
      matching: .url(slowURL),
      response: .custom(statusCode: 200, data: HTTPBody(Data()), headers: [:], delay: 0.15),
      requestCapture: { _ in slowStart.continuation.yield(1) },
      contextID: contextID
    )
    MockURLProtocol.stubSuccess(url: fastURL, contextID: contextID)

    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
    defer { session.invalidateAndCancel() }
    let recorder = NetworkTrafficRecorder()
    let client = NetworkClient(session: session, trafficRecorder: recorder)
    let slowRequest = HTTPRequest(method: .get, url: slowURL)
    let fastRequest = HTTPRequest(method: .get, url: fastURL)

    var startIterator = slowStart.stream.makeAsyncIterator()
    let slowTask = Task { try await client.execute(slowRequest) }
    let didStart = await startIterator.next()
    let fastTask = Task { try await client.execute(fastRequest) }
    _ = try await fastTask.value
    _ = try await slowTask.value
    slowStart.continuation.finish()

    let records = await recorder.records()
    let firstRecord = try #require(records.first)
    let lastRecord = try #require(records.last)
    #expect(didStart == 1)
    #expect(records.map(\.requestID) == [slowRequest.id, fastRequest.id])
    #expect(firstRecord.endedAt > lastRecord.endedAt)
  }
}

private final class MetricsTaskDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didFinishCollecting metrics: URLSessionTaskMetrics
  ) {
    lock.lock()
    count += 1
    lock.unlock()
  }

  func metricsCallbackCount() -> Int {
    lock.lock()
    let currentCount = count
    lock.unlock()
    return currentCount
  }
}

private final class AuthenticationTaskDelegate: NSObject, URLSessionTaskDelegate,
  @unchecked Sendable
{
  private let lock = NSLock()
  private var count = 0

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler:
      @escaping @Sendable (
        URLSession.AuthChallengeDisposition,
        URLCredential?
      ) -> Void
  ) {
    lock.lock()
    count += 1
    lock.unlock()
    completionHandler(.cancelAuthenticationChallenge, nil)
  }

  func challengeCount() -> Int {
    lock.lock()
    let currentCount = count
    lock.unlock()
    return currentCount
  }
}

private final class AuthenticationChallengeSender: NSObject, URLAuthenticationChallengeSender {
  func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}

  func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}

  func cancel(_ challenge: URLAuthenticationChallenge) {}

  func performDefaultHandling(for challenge: URLAuthenticationChallenge) {}

  func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {}
}
