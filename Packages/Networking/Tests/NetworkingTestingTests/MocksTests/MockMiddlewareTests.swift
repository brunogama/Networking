import Foundation
import Testing

@testable import NetworkingTesting
import NetworkingRuntime
import NetworkingObservability
import NetworkingDSL
import NetworkingRuntimeDSL
@Suite("Mock Middleware Tests")
struct MockMiddlewareTests {
    // MARK: - MockHTTPRequestMiddleware Tests

    @Test("MockHTTPRequestMiddleware applies transform when stubbed")
    func requestMiddleware_appliesTransform_whenStubbed() async throws {
        let mock = MockHTTPRequestMiddleware()
        mock.stubAddHeader("X-Custom", value: "test-value")

        let request = HTTPRequest(
            method: .get,
            url: URL(string: "https://api.example.com/users")!
        )

        let processed = try await mock.modifyRequest(request)

        #expect(processed.headers["X-Custom"] == "test-value")
    }

    @Test("MockHTTPRequestMiddleware passes through when no stub")
    func requestMiddleware_passesThrough_whenNoStub() async throws {
        let mock = MockHTTPRequestMiddleware()

        let request = HTTPRequest(
            method: .get,
            url: URL(string: "https://api.example.com/users")!
        )

        let processed = try await mock.modifyRequest(request)

        #expect(processed.url == request.url)
        #expect(processed.method == request.method)
    }

    @Test("MockHTTPRequestMiddleware throws when stub failure")
    func requestMiddleware_throws_whenStubFailure() async {
        let mock = MockHTTPRequestMiddleware()
        mock.stubFailure(URLError(.badURL))

        let request = HTTPRequest(
            method: .get,
            url: URL(string: "https://api.example.com")!
        )

        await #expect(throws: URLError.self) {
            _ = try await mock.modifyRequest(request)
        }
    }

    @Test("MockHTTPRequestMiddleware captures all requests")
    func requestMiddleware_capturesAllRequests() async throws {
        let mock = MockHTTPRequestMiddleware()

        let request1 = HTTPRequest(method: .get, url: URL(string: "https://example.com/1")!)
        let request2 = HTTPRequest(method: .post, url: URL(string: "https://example.com/2")!)

        _ = try await mock.modifyRequest(request1)
        _ = try await mock.modifyRequest(request2)

        let captured = mock.getCapturedRequests()
        #expect(captured.count == 2)
        #expect(captured[0].url.path == "/1")
        #expect(captured[1].url.path == "/2")
    }

    // MARK: - MockHTTPResponseMiddleware Tests

    @Test("MockHTTPResponseMiddleware applies transform when stubbed")
    func responseMiddleware_appliesTransform_whenStubbed() async throws {
        let mock = MockHTTPResponseMiddleware()
        let newBody = Data("transformed".utf8)
        mock.stubReplaceBody(newBody)

        let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
        let response = HTTPResponse(request: request, status: .ok, body: Data("original".utf8))

        let processed = try await mock.processResponse(response, for: request)

        #expect(processed.body == newBody)
    }

    @Test("MockHTTPResponseMiddleware passes through when no stub")
    func responseMiddleware_passesThrough_whenNoStub() async throws {
        let mock = MockHTTPResponseMiddleware()

        let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
        let response = HTTPResponse(request: request, status: .ok, body: Data("data".utf8))

        let processed = try await mock.processResponse(response, for: request)

        #expect(processed.body == response.body)
    }

    @Test("MockHTTPResponseMiddleware captures all responses")
    func responseMiddleware_capturesAllResponses() async throws {
        let mock = MockHTTPResponseMiddleware()

        let request = HTTPRequest(method: .get, url: URL(string: "https://example.com")!)
        let response1 = HTTPResponse(request: request, status: .ok)
        let response2 = HTTPResponse(request: request, status: .created)

        _ = try await mock.processResponse(response1, for: request)
        _ = try await mock.processResponse(response2, for: request)

        let captured = mock.getCapturedResponses()
        #expect(captured.count == 2)
        #expect(captured[0].response.status == .ok)
        #expect(captured[1].response.status == .created)
    }

    // MARK: - MockHTTPErrorMiddleware Tests

    @Test("MockHTTPErrorMiddleware tracks call count")
    func errorMiddleware_tracksCallCount() async throws {
        let mock = MockHTTPErrorMiddleware()
        mock.stubSwallow()

        let count = await mock.callCount
        #expect(count == 0)
    }
}
