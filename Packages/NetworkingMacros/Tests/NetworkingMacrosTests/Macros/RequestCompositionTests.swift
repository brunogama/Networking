import Testing
import Foundation
@testable import NetworkingMacros

@Suite("Request Composition Operator Tests")
struct RequestCompositionTests {

  let baseURL = URL(string: "https://api.example.com/users")!

  // MARK: - RequestModifier Tests

  @Test("bearerAuth modifier adds Authorization header")
  func testBearerAuth() {
    let request = HTTPRequest(method: .get, url: baseURL)
    let modified = request + .bearerAuth("my-token")
    #expect(modified.headers["Authorization"] == "Bearer my-token")
  }

  @Test("basicAuth modifier adds encoded Authorization header")
  func testBasicAuth() {
    let request = HTTPRequest(method: .get, url: baseURL)
    let modified = request + .basicAuth(username: "user", password: "pass")
    let expected = Data("user:pass".utf8).base64EncodedString()
    #expect(modified.headers["Authorization"] == "Basic \(expected)")
  }

  @Test("header modifier adds custom header")
  func testHeaderModifier() {
    let request = HTTPRequest(method: .get, url: baseURL)
    let modified = request + .header("X-Custom", "value")
    #expect(modified.headers["X-Custom"] == "value")
  }

  @Test("timeout modifier sets timeout")
  func testTimeoutModifier() {
    let request = HTTPRequest(method: .get, url: baseURL, timeout: 30.0)
    let modified = request + .timeout(60.0)
    #expect(modified.timeout == 60.0)
  }

  @Test("body modifier sets body data")
  func testBodyModifier() {
    let request = HTTPRequest(method: .post, url: baseURL)
    let body = "test".data(using: .utf8)!
    let modified = request + .body(body)
    #expect(modified.body == body)
  }

  @Test("jsonBody modifier sets body and Content-Type header")
  func testJsonBodyModifier() {
    let request = HTTPRequest(method: .post, url: baseURL)
    let body = #"{"key":"value"}"#.data(using: .utf8)!
    let modified = request + .jsonBody(body)
    #expect(modified.body == body)
    #expect(modified.headers["Content-Type"] == "application/json")
  }

  @Test("queryParam modifier appends query parameter")
  func testQueryParamModifier() {
    let request = HTTPRequest(method: .get, url: baseURL)
    let modified = request + .queryParam("page", "2")
    #expect(modified.url.absoluteString.contains("page=2"))
  }

  // MARK: - Chaining Multiple Modifiers

  @Test("chaining multiple modifiers")
  func testChaining() {
    let request = HTTPRequest(method: .get, url: baseURL)
    let modified =
      request
      + .bearerAuth("token")
      + .header("Accept", "application/json")
      + .timeout(15.0)

    #expect(modified.headers["Authorization"] == "Bearer token")
    #expect(modified.headers["Accept"] == "application/json")
    #expect(modified.timeout == 15.0)
    #expect(modified.method == .get)
    #expect(modified.url == baseURL)
  }

  // MARK: - Request + Request Composition

  @Test("request + request merges headers")
  func testRequestPlusRequest() {
    let base = HTTPRequest(
      method: .post,
      url: baseURL,
      headers: ["Content-Type": "application/json"]
    )
    let extra = HTTPRequest(
      method: .get,
      url: URL(string: "https://other.com")!,
      headers: ["Authorization": "Bearer token"]
    )

    let merged = base + extra
    #expect(merged.method == .post)  // Left takes precedence for method
    #expect(merged.url == baseURL)  // Left takes precedence for URL
    #expect(merged.headers["Content-Type"] == "application/json")
    #expect(merged.headers["Authorization"] == "Bearer token")
  }

  // MARK: - JSON Convenience

  @Test("json modifier encodes Encodable value")
  func testJsonConvenience() {
    struct Payload: Encodable {
      let name: String
    }

    let request = HTTPRequest(method: .post, url: baseURL)
    let modified = request + .json(Payload(name: "Test"))
    #expect(modified.body != nil)
    #expect(modified.headers["Content-Type"] == "application/json")
  }

  // MARK: - Immutability

  @Test("original request is not modified")
  func testImmutability() {
    let original = HTTPRequest(method: .get, url: baseURL)
    _ = original + .bearerAuth("token")

    #expect(original.headers["Authorization"] == nil)
    #expect(original.timeout == 30.0)
  }
}
