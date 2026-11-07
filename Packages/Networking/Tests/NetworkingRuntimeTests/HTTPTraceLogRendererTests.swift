import Foundation
import NetworkingCore
import Testing
@testable import NetworkingRuntime

@Suite("HTTP trace log rendering")
struct HTTPTraceLogRendererTests {
  @Test("cURL and HTTPie formats preserve a sanitized request")
  func commandFormats() throws {
    let trace = try trace()
    let codec = JSONCodec()
    let curl = HTTPTraceLogRenderer.render(trace, format: .curl, codec: codec)
    let httpie = HTTPTraceLogRenderer.render(trace, format: .httpie, codec: codec)

    #expect(curl.starts(with: "curl --request POST"))
    #expect(curl.contains("Authorization: <redacted>"))
    #expect(curl.contains("--data-raw"))
    #expect(httpie.starts(with: "http POST"))
    #expect(httpie.contains("Authorization:<redacted>"))
    #expect(httpie.contains("--raw"))
  }

  @Test("Trace format emits a complete sanitized JSON record")
  func traceFormat() throws {
    let output = HTTPTraceLogRenderer.render(try trace(), format: .trace, codec: JSONCodec())

    #expect(output.contains("POST"))
    #expect(output.contains("<redacted>"))
  }

  private func trace() throws -> HTTPTrace {
    let url = try #require(URL(string: "https://example.test/users?token=%3Credacted%3E"))
    return HTTPTrace(
      id: HTTPTraceID(),
      request: HTTPTrace.Message(
        method: "POST",
        url: url,
        statusCode: nil,
        headers: ["Authorization": "<redacted>"],
        body: Data("{\"name\":\"Blob\"}".utf8)
      ),
      startedAt: Date()
    )
  }
}
