import Foundation
import Networking
import Testing

@Test("The standalone Networking product constructs a request without macros")
private func standaloneNetworkingConsumer() throws {
  let url = try #require(URL(string: "https://example.com/users/42"))
  let request = HTTPRequest(method: .get, url: url)

  #expect(request.method == .get)
  #expect(request.url.rawValue == url)
  #expect(request.body == nil)
}

@Test("Headers convert explicitly at the consumer boundary")
private func headerRawValueRoundTrip() {
  let examples: [[String: String]] = [
    [:],
    ["Accept": "application/json"],
    ["X-Request-ID": "123", "Authorization": "Bearer token"],
  ]

  for rawValue in examples {
    let headers = HTTPHeaders(rawValue: rawValue)
    #expect(headers.rawValue == rawValue)
  }
}

@Test(
  "Header conversion preserves generated name and value pairs",
  arguments: ["", "X-Test", "x-test", String(repeating: "A", count: 256)],
  ["", "value", "café", String(repeating: "v", count: 1024)]
)
private func generatedHeaderRawValueRoundTrip(name: String, value: String) {
  let rawValue = [name: value]
  #expect(HTTPHeaders(rawValue: rawValue).rawValue == rawValue)
}
