import Foundation
import NetworkingCore
import NetworkingTesting
import Testing

struct MockURLProtocolCancellationTests {
  @Test("A reentrant stop prevents later data and completion callbacks")
  func stopPreventsFurtherCallbacks() throws {
    let context = MockContextIdentifier()
    let url = try #require(URL(string: "https://cancel.example.com/immediate"))
    defer { MockURLProtocol.clearAll(contextID: context) }
    MockURLProtocol.stubSuccess(url: HTTPRequestURL(url), contextID: context)
    var request = URLRequest(url: url)
    request.setValue(context.rawValue.uuidString, forHTTPHeaderField: "X-Networking-Mock-Context")
    let recorder = StoppingProtocolClient()
    let loader = MockURLProtocol(request: request, cachedResponse: nil, client: recorder)

    loader.startLoading()

    #expect(recorder.events == ["response"])
  }

  @Test("Cancelling a delayed session request ends its wait")
  func cancelledSessionRequestFinishes() async throws {
    let context = MockContextIdentifier()
    let url = try #require(URL(string: "https://cancel.example.com/delayed"))
    defer { MockURLProtocol.clearAll(contextID: context) }
    let (started, signal) = AsyncStream<Void>.makeStream()
    MockURLProtocol.stub(
      matching: .url(HTTPRequestURL(url)),
      response: .custom(statusCode: 200, data: HTTPBody(Data()), headers: [:], delay: 60),
      requestCapture: { _ in
        signal.yield(())
        signal.finish()
      },
      contextID: context
    )
    let session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: context)
    )
    defer { session.invalidateAndCancel() }

    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        do {
          _ = try await session.data(from: url)
          Issue.record("Expected cancellation")
        } catch {
          #expect((error as? URLError)?.code == .cancelled)
        }
      }
      for await _ in started { break }
      group.cancelAll()
    }
  }
}
